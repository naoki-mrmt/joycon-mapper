//! Joy-Con input handling via macOS IOHIDManager with callback-based input
//!
//! This implementation uses IOHIDManagerRegisterInputValueCallback to receive
//! input values without requiring exclusive device access. This allows reading
//! Joy-Con input while gamecontrollerd is running.

use crate::error::{AppError, JoyConError};
use super::button::{JoyConButton, ButtonEvent};
use super::stick::StickPosition;

use core_foundation::base::{CFRelease, TCFType, kCFAllocatorDefault};
use core_foundation::array::CFArray;
use core_foundation::dictionary::CFDictionary;
use core_foundation::number::CFNumber;
use core_foundation::runloop::{CFRunLoopGetCurrent, CFRunLoopRunInMode, kCFRunLoopDefaultMode};
use core_foundation::string::CFString;
use io_kit_sys::hid::base::{IOHIDDeviceRef, IOHIDValueRef};
use io_kit_sys::hid::device::IOHIDDeviceGetProperty;
use io_kit_sys::hid::element::{IOHIDElementGetUsage, IOHIDElementGetUsagePage, IOHIDElementGetDevice};
use io_kit_sys::hid::keys::{
    kIOHIDProductIDKey, kIOHIDProductKey, kIOHIDSerialNumberKey,
    kIOHIDVendorIDKey,
};
use io_kit_sys::hid::manager::{
    IOHIDManagerCopyDevices, IOHIDManagerCreate, IOHIDManagerOpen, IOHIDManagerClose,
    IOHIDManagerRef, IOHIDManagerScheduleWithRunLoop, IOHIDManagerSetDeviceMatchingMultiple,
    IOHIDManagerRegisterInputValueCallback, kIOHIDManagerOptionNone,
};
use io_kit_sys::hid::value::{IOHIDValueGetElement, IOHIDValueGetIntegerValue};
use io_kit_sys::ret::kIOReturnSuccess;
use std::collections::HashMap;
use std::ffi::c_void;
use std::ptr;
use std::sync::{Arc, Mutex};

/// Nintendo Vendor ID
const NINTENDO_VENDOR_ID: i32 = 0x057E;
/// Joy-Con (L) Product ID
const JOYCON_L_PRODUCT_ID: i32 = 0x2006;
/// Joy-Con (R) Product ID
const JOYCON_R_PRODUCT_ID: i32 = 0x2007;
/// Pro Controller Product ID
const PRO_CONTROLLER_PRODUCT_ID: i32 = 0x2009;

/// HID Usage Pages
const USAGE_PAGE_GENERIC_DESKTOP: u32 = 0x01;
const USAGE_PAGE_BUTTON: u32 = 0x09;

/// HID Usages for Generic Desktop
const USAGE_X: u32 = 0x30;
const USAGE_Y: u32 = 0x31;
const USAGE_HAT_SWITCH: u32 = 0x39;

/// Joy-Con device info
#[derive(Debug, Clone)]
pub struct JoyConInfo {
    pub name: String,
    pub serial: Option<String>,
    pub device_type: JoyConDeviceType,
}

/// Joy-Con device type
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JoyConDeviceType {
    Left,
    Right,
    ProController,
    Unknown,
}

impl std::fmt::Display for JoyConDeviceType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            JoyConDeviceType::Left => write!(f, "Joy-Con (L)"),
            JoyConDeviceType::Right => write!(f, "Joy-Con (R)"),
            JoyConDeviceType::ProController => write!(f, "Pro Controller"),
            JoyConDeviceType::Unknown => write!(f, "Unknown"),
        }
    }
}

/// Shared state for callback-based input
#[derive(Debug, Clone, Default)]
struct CallbackState {
    /// Button states by button number (1-indexed HID buttons)
    buttons: HashMap<u32, bool>,
    /// Stick X position (0-255 range)
    stick_x: u8,
    /// Stick Y position (0-255 range)
    stick_y: u8,
    /// Hat switch value (for D-pad)
    hat_switch: u8,
    /// Whether any input has been received
    has_input: bool,
}

/// Context passed to the HID callback
struct CallbackContext {
    state: Arc<Mutex<CallbackState>>,
    target_device: Option<IOHIDDeviceRef>,
}

/// Joy-Con connection manager using callback-based input
pub struct JoyConManager {
    hid_manager: IOHIDManagerRef,
    callback_context: Box<CallbackContext>,
    manager_opened: bool,
}

impl JoyConManager {
    pub fn new() -> Result<Self, AppError> {
        unsafe {
            let hid_manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
            if hid_manager.is_null() {
                return Err(JoyConError::InitError("Failed to create IOHIDManager".to_string()).into());
            }

            // Set up matching dictionary for Nintendo devices
            let matching_dict = create_nintendo_matching_dict();
            let matching_array = CFArray::from_CFTypes(&[matching_dict]);
            IOHIDManagerSetDeviceMatchingMultiple(hid_manager, matching_array.as_concrete_TypeRef());

            // Create callback context with shared state
            let callback_context = Box::new(CallbackContext {
                state: Arc::new(Mutex::new(CallbackState::default())),
                target_device: None,
            });

            // Register input value callback
            let context_ptr = &*callback_context as *const CallbackContext as *mut c_void;
            IOHIDManagerRegisterInputValueCallback(
                hid_manager,
                Some(input_value_callback),
                context_ptr,
            );

            // Schedule with run loop
            IOHIDManagerScheduleWithRunLoop(
                hid_manager,
                CFRunLoopGetCurrent(),
                kCFRunLoopDefaultMode,
            );

            // Try to open the manager with no options
            // Note: On macOS, gamecontrollerd may hold exclusive access, causing this to fail
            // We'll still try to receive callbacks even if open fails
            let result = IOHIDManagerOpen(hid_manager, kIOHIDManagerOptionNone);
            let manager_opened = result == kIOReturnSuccess;

            if !manager_opened {
                eprintln!("[DEBUG] IOHIDManagerOpen returned: 0x{:08X} - callbacks may not work", result);
                eprintln!("[DEBUG] gamecontrollerd likely has exclusive access");
                eprintln!("[DEBUG] Consider using: sudo launchctl bootout system/com.apple.gamecontrollerd");
            }

            // Run the run loop briefly to allow device enumeration
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, 0);

            Ok(Self {
                hid_manager,
                callback_context,
                manager_opened,
            })
        }
    }

    /// List connected Joy-Con devices
    pub fn list_devices(&self) -> Result<Vec<JoyConInfo>, AppError> {
        let mut devices = Vec::new();

        unsafe {
            let device_set = IOHIDManagerCopyDevices(self.hid_manager);
            if device_set.is_null() {
                return Ok(devices);
            }

            let count = core_foundation_sys::set::CFSetGetCount(
                device_set as core_foundation_sys::set::CFSetRef
            );

            if count == 0 {
                CFRelease(device_set as *mut c_void);
                return Ok(devices);
            }

            let mut device_refs: Vec<*const c_void> = vec![ptr::null(); count as usize];
            core_foundation_sys::set::CFSetGetValues(
                device_set as core_foundation_sys::set::CFSetRef,
                device_refs.as_mut_ptr(),
            );

            for device_ref in device_refs {
                let device = device_ref as IOHIDDeviceRef;
                if device.is_null() {
                    continue;
                }

                let vendor_id = get_device_int_property(device, kIOHIDVendorIDKey);
                let product_id = get_device_int_property(device, kIOHIDProductIDKey);

                // Only list Nintendo devices
                if vendor_id != NINTENDO_VENDOR_ID as i64 {
                    continue;
                }

                let device_type = match product_id as i32 {
                    JOYCON_L_PRODUCT_ID => JoyConDeviceType::Left,
                    JOYCON_R_PRODUCT_ID => JoyConDeviceType::Right,
                    PRO_CONTROLLER_PRODUCT_ID => JoyConDeviceType::ProController,
                    _ => JoyConDeviceType::Unknown,
                };

                let name = get_device_string_property(device, kIOHIDProductKey)
                    .unwrap_or_else(|| format!("{}", device_type));
                let serial = get_device_string_property(device, kIOHIDSerialNumberKey);

                devices.push(JoyConInfo {
                    name,
                    serial,
                    device_type,
                });
            }

            CFRelease(device_set as *mut c_void);
        }

        Ok(devices)
    }

    /// Connect to first available Joy-Con Left
    pub fn connect_left(&mut self) -> Result<JoyConConnection, AppError> {
        self.connect_device(Some(JoyConDeviceType::Left))
    }

    /// Connect to any available Joy-Con
    pub fn connect(&mut self) -> Result<JoyConConnection, AppError> {
        self.connect_device(None)
    }

    fn connect_device(&mut self, target_type: Option<JoyConDeviceType>) -> Result<JoyConConnection, AppError> {
        unsafe {
            let device_set = IOHIDManagerCopyDevices(self.hid_manager);
            if device_set.is_null() {
                return Err(JoyConError::NotFound.into());
            }

            let count = core_foundation_sys::set::CFSetGetCount(
                device_set as core_foundation_sys::set::CFSetRef
            );

            if count == 0 {
                CFRelease(device_set as *mut c_void);
                return Err(JoyConError::NotFound.into());
            }

            let mut device_refs: Vec<*const c_void> = vec![ptr::null(); count as usize];
            core_foundation_sys::set::CFSetGetValues(
                device_set as core_foundation_sys::set::CFSetRef,
                device_refs.as_mut_ptr(),
            );

            for device_ref in device_refs {
                let device = device_ref as IOHIDDeviceRef;
                if device.is_null() {
                    continue;
                }

                let vendor_id = get_device_int_property(device, kIOHIDVendorIDKey);
                let product_id = get_device_int_property(device, kIOHIDProductIDKey);

                if vendor_id != NINTENDO_VENDOR_ID as i64 {
                    continue;
                }

                let device_type = match product_id as i32 {
                    JOYCON_L_PRODUCT_ID => JoyConDeviceType::Left,
                    JOYCON_R_PRODUCT_ID => JoyConDeviceType::Right,
                    PRO_CONTROLLER_PRODUCT_ID => JoyConDeviceType::ProController,
                    _ => continue,
                };

                // Check if this matches our target type
                if let Some(target) = target_type {
                    if device_type != target {
                        continue;
                    }
                }

                // Store the target device in callback context for filtering
                self.callback_context.target_device = Some(device);

                // Clear previous state
                if let Ok(mut state) = self.callback_context.state.lock() {
                    *state = CallbackState::default();
                }

                CFRelease(device_set as *mut c_void);

                // Return connection that reads from shared callback state
                // We do NOT call IOHIDDeviceOpen - the manager's callback handles input
                return Ok(JoyConConnection::new(
                    device,
                    device_type,
                    Arc::clone(&self.callback_context.state),
                ));
            }

            CFRelease(device_set as *mut c_void);
        }

        Err(JoyConError::NotFound.into())
    }

    /// Process pending HID events (must be called regularly)
    pub fn process_events(&self) {
        unsafe {
            // Run the run loop briefly to process callbacks
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.001, 0);
        }
    }
}

impl Drop for JoyConManager {
    fn drop(&mut self) {
        unsafe {
            if self.manager_opened {
                IOHIDManagerClose(self.hid_manager, kIOHIDManagerOptionNone);
            }
            CFRelease(self.hid_manager as *mut c_void);
        }
    }
}

/// Input value callback - receives HID values from the manager
unsafe extern "C" fn input_value_callback(
    context: *mut c_void,
    _result: io_kit_sys::ret::IOReturn,
    _sender: *mut c_void,
    value: IOHIDValueRef,
) {
    if context.is_null() || value.is_null() {
        return;
    }

    let ctx = &*(context as *const CallbackContext);

    // Get the device that sent this value
    let element = IOHIDValueGetElement(value);
    if element.is_null() {
        return;
    }

    let device = IOHIDElementGetDevice(element);

    // Filter by target device if set
    if let Some(target) = ctx.target_device {
        if device != target {
            return;
        }
    }

    // Get element usage info
    let usage_page = IOHIDElementGetUsagePage(element);
    let usage = IOHIDElementGetUsage(element);
    let int_value = IOHIDValueGetIntegerValue(value);

    // Lock state and update
    if let Ok(mut state) = ctx.state.lock() {
        state.has_input = true;

        match usage_page {
            USAGE_PAGE_BUTTON => {
                // Button state (usage is the button number, 1-indexed)
                state.buttons.insert(usage, int_value != 0);
            }
            USAGE_PAGE_GENERIC_DESKTOP => {
                match usage {
                    USAGE_X => {
                        // Stick X axis
                        state.stick_x = int_value.clamp(0, 255) as u8;
                    }
                    USAGE_Y => {
                        // Stick Y axis
                        state.stick_y = int_value.clamp(0, 255) as u8;
                    }
                    USAGE_HAT_SWITCH => {
                        // D-pad as hat switch
                        state.hat_switch = int_value.clamp(0, 8) as u8;
                    }
                    _ => {}
                }
            }
            _ => {}
        }
    }
}

/// Active Joy-Con connection using callback-based state
pub struct JoyConConnection {
    #[allow(dead_code)]
    device: IOHIDDeviceRef,
    device_type: JoyConDeviceType,
    shared_state: Arc<Mutex<CallbackState>>,
    previous_state: ControllerState,
}

#[derive(Debug, Clone, Default)]
struct ControllerState {
    up: bool,
    down: bool,
    left: bool,
    right: bool,
    l: bool,
    zl: bool,
    minus: bool,
    capture: bool,
    stick_click: bool,
    sl: bool,
    sr: bool,
    stick_x: f32,
    stick_y: f32,
}

impl JoyConConnection {
    fn new(
        device: IOHIDDeviceRef,
        device_type: JoyConDeviceType,
        shared_state: Arc<Mutex<CallbackState>>,
    ) -> Self {
        Self {
            device,
            device_type,
            shared_state,
            previous_state: ControllerState::default(),
        }
    }

    /// Poll for input events
    pub fn poll(&mut self) -> Result<Vec<InputEvent>, AppError> {
        // Process pending callbacks
        unsafe {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.001, 0);
        }

        let current = self.read_state()?;
        let events = self.diff_state(&current);
        self.previous_state = current;
        Ok(events)
    }

    /// Get current state
    pub fn current_state(&self) -> JoyConState {
        let mut buttons = Vec::new();

        if self.previous_state.up { buttons.push(JoyConButton::Up); }
        if self.previous_state.down { buttons.push(JoyConButton::Down); }
        if self.previous_state.left { buttons.push(JoyConButton::Left); }
        if self.previous_state.right { buttons.push(JoyConButton::Right); }
        if self.previous_state.l { buttons.push(JoyConButton::L); }
        if self.previous_state.zl { buttons.push(JoyConButton::Zl); }
        if self.previous_state.minus { buttons.push(JoyConButton::Minus); }
        if self.previous_state.capture { buttons.push(JoyConButton::Capture); }
        if self.previous_state.stick_click { buttons.push(JoyConButton::StickClick); }
        if self.previous_state.sl { buttons.push(JoyConButton::Sl); }
        if self.previous_state.sr { buttons.push(JoyConButton::Sr); }

        JoyConState {
            buttons_pressed: buttons,
            stick: StickPosition::new(self.previous_state.stick_x, self.previous_state.stick_y),
        }
    }

    fn read_state(&self) -> Result<ControllerState, AppError> {
        let callback_state = self.shared_state.lock()
            .map_err(|_| JoyConError::ReadError("Failed to lock state".to_string()))?;

        // If no input received yet, return default state
        if !callback_state.has_input {
            return Ok(ControllerState::default());
        }

        // Convert callback state to controller state
        // Joy-Con Left button mapping (HID buttons are 1-indexed):
        // The exact mapping depends on how gamecontrollerd presents the Joy-Con
        // We'll map based on common HID button numbers

        let state = if self.device_type == JoyConDeviceType::Left {
            // Joy-Con Left mapping
            // Hat switch values for D-pad: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW, 8=neutral
            let (up, right, down, left) = match callback_state.hat_switch {
                0 => (true, false, false, false),  // N
                1 => (true, true, false, false),   // NE
                2 => (false, true, false, false),  // E
                3 => (false, true, true, false),   // SE
                4 => (false, false, true, false),  // S
                5 => (false, false, true, true),   // SW
                6 => (false, false, false, true),  // W
                7 => (true, false, false, true),   // NW
                _ => (false, false, false, false), // neutral
            };

            ControllerState {
                up,
                down,
                left,
                right,
                // Button mappings - these may need adjustment based on actual HID report
                // Typical Joy-Con L buttons: L, ZL, Minus, Capture, Stick, SL, SR
                l: *callback_state.buttons.get(&5).unwrap_or(&false),
                zl: *callback_state.buttons.get(&7).unwrap_or(&false),
                minus: *callback_state.buttons.get(&9).unwrap_or(&false),
                capture: *callback_state.buttons.get(&14).unwrap_or(&false),
                stick_click: *callback_state.buttons.get(&11).unwrap_or(&false),
                sl: *callback_state.buttons.get(&15).unwrap_or(&false),
                sr: *callback_state.buttons.get(&16).unwrap_or(&false),
                // Convert 0-255 to -1.0 to 1.0
                stick_x: (callback_state.stick_x as f32 - 128.0) / 128.0,
                stick_y: (callback_state.stick_y as f32 - 128.0) / 128.0,
            }
        } else {
            // Joy-Con Right or Pro Controller
            let (up, right, down, left) = match callback_state.hat_switch {
                0 => (true, false, false, false),
                1 => (true, true, false, false),
                2 => (false, true, false, false),
                3 => (false, true, true, false),
                4 => (false, false, true, false),
                5 => (false, false, true, true),
                6 => (false, false, false, true),
                7 => (true, false, false, true),
                _ => (false, false, false, false),
            };

            ControllerState {
                up,
                down,
                left,
                right,
                l: *callback_state.buttons.get(&5).unwrap_or(&false),
                zl: *callback_state.buttons.get(&7).unwrap_or(&false),
                minus: *callback_state.buttons.get(&9).unwrap_or(&false),
                capture: *callback_state.buttons.get(&14).unwrap_or(&false),
                stick_click: *callback_state.buttons.get(&11).unwrap_or(&false),
                sl: *callback_state.buttons.get(&15).unwrap_or(&false),
                sr: *callback_state.buttons.get(&16).unwrap_or(&false),
                stick_x: (callback_state.stick_x as f32 - 128.0) / 128.0,
                stick_y: (callback_state.stick_y as f32 - 128.0) / 128.0,
            }
        };

        Ok(state)
    }

    fn diff_state(&self, current: &ControllerState) -> Vec<InputEvent> {
        let mut events = Vec::new();
        let prev = &self.previous_state;

        // D-pad
        self.check_button(&mut events, JoyConButton::Up, prev.up, current.up);
        self.check_button(&mut events, JoyConButton::Down, prev.down, current.down);
        self.check_button(&mut events, JoyConButton::Left, prev.left, current.left);
        self.check_button(&mut events, JoyConButton::Right, prev.right, current.right);

        // Shoulder buttons
        self.check_button(&mut events, JoyConButton::L, prev.l, current.l);
        self.check_button(&mut events, JoyConButton::Zl, prev.zl, current.zl);

        // Other buttons
        self.check_button(&mut events, JoyConButton::Minus, prev.minus, current.minus);
        self.check_button(&mut events, JoyConButton::Capture, prev.capture, current.capture);
        self.check_button(&mut events, JoyConButton::StickClick, prev.stick_click, current.stick_click);
        self.check_button(&mut events, JoyConButton::Sl, prev.sl, current.sl);
        self.check_button(&mut events, JoyConButton::Sr, prev.sr, current.sr);

        // Stick
        if (current.stick_x - prev.stick_x).abs() > 0.01
            || (current.stick_y - prev.stick_y).abs() > 0.01
        {
            events.push(InputEvent::Stick(StickPosition::new(current.stick_x, current.stick_y)));
        }

        events
    }

    fn check_button(&self, events: &mut Vec<InputEvent>, button: JoyConButton, prev: bool, current: bool) {
        if !prev && current {
            events.push(InputEvent::Button(ButtonEvent::pressed(button)));
        } else if prev && !current {
            events.push(InputEvent::Button(ButtonEvent::released(button)));
        }
    }
}

// Note: JoyConConnection no longer needs Drop implementation since we don't open the device

/// Joy-Con input state
#[derive(Debug, Clone, Default)]
pub struct JoyConState {
    pub buttons_pressed: Vec<JoyConButton>,
    pub stick: StickPosition,
}

/// Input event from Joy-Con
#[derive(Debug, Clone)]
pub enum InputEvent {
    Button(ButtonEvent),
    Stick(StickPosition),
}

// ============================================================================
// Helper functions for IOKit HID
// ============================================================================

/// Create matching dictionary for Nintendo devices
fn create_nintendo_matching_dict() -> CFDictionary<CFString, CFNumber> {
    let vendor_key = CFString::new("VendorID");
    let vendor_value = CFNumber::from(NINTENDO_VENDOR_ID);

    CFDictionary::from_CFType_pairs(&[(vendor_key, vendor_value)])
}

/// Get an integer property from an HID device
unsafe fn get_device_int_property(device: IOHIDDeviceRef, key: *const i8) -> i64 {
    let key_str = std::ffi::CStr::from_ptr(key).to_str().unwrap_or("");
    let key_cfstr = CFString::new(key_str);
    let value = IOHIDDeviceGetProperty(device, key_cfstr.as_concrete_TypeRef() as *mut _);

    if value.is_null() {
        return 0;
    }

    let cf_number = core_foundation::number::CFNumber::wrap_under_get_rule(
        value as core_foundation::number::CFNumberRef
    );

    cf_number.to_i64().unwrap_or(0)
}

/// Get a string property from an HID device
unsafe fn get_device_string_property(device: IOHIDDeviceRef, key: *const i8) -> Option<String> {
    let key_str = std::ffi::CStr::from_ptr(key).to_str().unwrap_or("");
    let key_cfstr = CFString::new(key_str);
    let value = IOHIDDeviceGetProperty(device, key_cfstr.as_concrete_TypeRef() as *mut _);

    if value.is_null() {
        return None;
    }

    let cf_string = CFString::wrap_under_get_rule(value as core_foundation::string::CFStringRef);
    Some(cf_string.to_string())
}
