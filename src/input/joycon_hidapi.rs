//! Joy-Con input handling via hidapi crate
//!
//! This is an alternative implementation that uses the hidapi crate
//! which may work when the native IOHIDManager is blocked by gamecontrollerd.

#[cfg(feature = "hidapi")]
use hidapi::{HidApi, HidDevice};

use crate::error::{AppError, JoyConError};
use super::button::{JoyConButton, ButtonEvent};
use super::stick::StickPosition;
use super::joycon::{JoyConInfo, JoyConDeviceType, JoyConState, InputEvent};

/// Nintendo Vendor ID
const NINTENDO_VENDOR_ID: u16 = 0x057E;
/// Joy-Con (L) Product ID
const JOYCON_L_PRODUCT_ID: u16 = 0x2006;
/// Joy-Con (R) Product ID
const JOYCON_R_PRODUCT_ID: u16 = 0x2007;
/// Pro Controller Product ID
const PRO_CONTROLLER_PRODUCT_ID: u16 = 0x2009;

/// Joy-Con manager using hidapi
#[cfg(feature = "hidapi")]
pub struct HidApiJoyConManager {
    api: HidApi,
}

#[cfg(feature = "hidapi")]
impl HidApiJoyConManager {
    pub fn new() -> Result<Self, AppError> {
        let api = HidApi::new()
            .map_err(|e| JoyConError::InitError(format!("Failed to initialize hidapi: {}", e)))?;

        Ok(Self { api })
    }

    /// Refresh device list
    pub fn refresh(&mut self) -> Result<(), AppError> {
        self.api.refresh_devices()
            .map_err(|e| JoyConError::InitError(format!("Failed to refresh devices: {}", e)))?;
        Ok(())
    }

    /// List connected Joy-Con devices
    pub fn list_devices(&self) -> Result<Vec<JoyConInfo>, AppError> {
        let mut devices = Vec::new();

        for device in self.api.device_list() {
            if device.vendor_id() != NINTENDO_VENDOR_ID {
                continue;
            }

            let device_type = match device.product_id() {
                JOYCON_L_PRODUCT_ID => JoyConDeviceType::Left,
                JOYCON_R_PRODUCT_ID => JoyConDeviceType::Right,
                PRO_CONTROLLER_PRODUCT_ID => JoyConDeviceType::ProController,
                _ => continue,
            };

            let name = device.product_string()
                .map(|s| s.to_string())
                .unwrap_or_else(|| format!("{}", device_type));

            let serial = device.serial_number()
                .map(|s| s.to_string());

            devices.push(JoyConInfo {
                name,
                serial,
                device_type,
            });
        }

        Ok(devices)
    }

    /// Connect to first available Joy-Con Left
    pub fn connect_left(&self) -> Result<HidApiJoyConConnection, AppError> {
        self.connect_device(Some(JoyConDeviceType::Left))
    }

    /// Connect to any available Joy-Con
    pub fn connect(&self) -> Result<HidApiJoyConConnection, AppError> {
        self.connect_device(None)
    }

    fn connect_device(&self, target_type: Option<JoyConDeviceType>) -> Result<HidApiJoyConConnection, AppError> {
        for device_info in self.api.device_list() {
            if device_info.vendor_id() != NINTENDO_VENDOR_ID {
                continue;
            }

            let device_type = match device_info.product_id() {
                JOYCON_L_PRODUCT_ID => JoyConDeviceType::Left,
                JOYCON_R_PRODUCT_ID => JoyConDeviceType::Right,
                PRO_CONTROLLER_PRODUCT_ID => JoyConDeviceType::ProController,
                _ => continue,
            };

            if let Some(target) = target_type {
                if device_type != target {
                    continue;
                }
            }

            // Try to open the device
            match device_info.open_device(&self.api) {
                Ok(device) => {
                    // Set non-blocking mode
                    if let Err(e) = device.set_blocking_mode(false) {
                        eprintln!("[DEBUG] Warning: Failed to set non-blocking mode: {}", e);
                    }

                    return Ok(HidApiJoyConConnection::new(device, device_type));
                }
                Err(e) => {
                    eprintln!("[DEBUG] Failed to open device via hidapi: {}", e);
                    continue;
                }
            }
        }

        Err(JoyConError::NotFound.into())
    }
}

/// Joy-Con connection using hidapi
#[cfg(feature = "hidapi")]
pub struct HidApiJoyConConnection {
    device: HidDevice,
    device_type: JoyConDeviceType,
    previous_state: ControllerState,
    report_buffer: [u8; 64],
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

#[cfg(feature = "hidapi")]
impl HidApiJoyConConnection {
    fn new(device: HidDevice, device_type: JoyConDeviceType) -> Self {
        Self {
            device,
            device_type,
            previous_state: ControllerState::default(),
            report_buffer: [0u8; 64],
        }
    }

    /// Poll for input events
    pub fn poll(&mut self) -> Result<Vec<InputEvent>, AppError> {
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

    fn read_state(&mut self) -> Result<ControllerState, AppError> {
        // Try to read a report (non-blocking)
        match self.device.read(&mut self.report_buffer) {
            Ok(0) => {
                // No data available, return previous state
                Ok(self.previous_state.clone())
            }
            Ok(len) => {
                // Parse the report
                self.parse_report(len)
            }
            Err(e) => {
                // Read error - might be temporary
                eprintln!("[DEBUG] HID read error: {}", e);
                Ok(self.previous_state.clone())
            }
        }
    }

    /// Parse Joy-Con HID report
    /// The format depends on the report ID:
    /// - 0x3F: Simple HID mode (used by macOS)
    /// - 0x21/0x30/0x31: Standard full mode
    fn parse_report(&self, len: usize) -> Result<ControllerState, AppError> {
        if len < 2 {
            return Ok(self.previous_state.clone());
        }

        // Check report ID
        let report_id = self.report_buffer[0];

        match report_id {
            0x3F => self.parse_simple_hid_report(),
            0x21 | 0x30 | 0x31 => self.parse_standard_report(),
            _ => {
                // Unknown report, return previous state
                Ok(self.previous_state.clone())
            }
        }
    }

    /// Parse SimpleHID (0x3F) report format
    fn parse_simple_hid_report(&self) -> Result<ControllerState, AppError> {
        // SimpleHID format (when report_id is 0x3F):
        // Byte 1: Button state 1
        // Byte 2: Button state 2
        // Byte 3: Hat switch (D-pad)
        // Byte 4: Stick X
        // Byte 5: Stick Y

        let buttons1 = self.report_buffer[1];
        let buttons2 = self.report_buffer[2];
        let hat = self.report_buffer[3];
        let stick_x_raw = self.report_buffer[4];
        let stick_y_raw = self.report_buffer[5];

        // Hat switch to D-pad conversion
        let (up, right, down, left) = match hat {
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

        let state = ControllerState {
            up,
            down,
            left,
            right,
            // Button mapping for SimpleHID mode
            l: (buttons1 & 0x40) != 0,
            zl: (buttons1 & 0x80) != 0,
            minus: (buttons2 & 0x01) != 0,
            capture: (buttons2 & 0x20) != 0,
            stick_click: (buttons2 & 0x04) != 0,
            sl: (buttons1 & 0x10) != 0,
            sr: (buttons1 & 0x20) != 0,
            stick_x: (stick_x_raw as f32 - 128.0) / 128.0,
            stick_y: (stick_y_raw as f32 - 128.0) / 128.0,
        };

        Ok(state)
    }

    /// Parse standard report format (0x21, 0x30, 0x31)
    fn parse_standard_report(&self) -> Result<ControllerState, AppError> {
        // Standard report format:
        // Byte 1: Timer
        // Byte 2: Battery + connection
        // Byte 3-5: Button state (3 bytes)
        // Byte 6-11: Stick data (6 bytes)
        // ...

        if self.report_buffer.len() < 12 {
            return Ok(self.previous_state.clone());
        }

        let buttons1 = self.report_buffer[3];
        let buttons2 = self.report_buffer[4];
        let _buttons3 = self.report_buffer[5];

        // Left stick data (bytes 6-8)
        let stick_data = &self.report_buffer[6..9];
        let stick_x_raw = stick_data[0] as u16 | ((stick_data[1] as u16 & 0x0F) << 8);
        let stick_y_raw = ((stick_data[1] as u16) >> 4) | ((stick_data[2] as u16) << 4);

        // Convert 12-bit stick values to -1.0 to 1.0
        let stick_x = (stick_x_raw as f32 - 2048.0) / 2048.0;
        let stick_y = (stick_y_raw as f32 - 2048.0) / 2048.0;

        let state = if self.device_type == JoyConDeviceType::Left {
            ControllerState {
                // D-pad on Joy-Con L (when held sideways these become ABXY-like)
                down: (buttons1 & 0x01) != 0,
                right: (buttons1 & 0x02) != 0,
                left: (buttons1 & 0x04) != 0,
                up: (buttons1 & 0x08) != 0,
                sl: (buttons1 & 0x10) != 0,
                sr: (buttons1 & 0x20) != 0,
                l: (buttons2 & 0x40) != 0,
                zl: (buttons2 & 0x80) != 0,
                minus: (buttons2 & 0x01) != 0,
                capture: (buttons2 & 0x20) != 0,
                stick_click: (buttons2 & 0x08) != 0,
                stick_x,
                stick_y,
            }
        } else {
            // Joy-Con R or Pro Controller
            ControllerState {
                up: (buttons1 & 0x08) != 0,
                down: (buttons1 & 0x01) != 0,
                left: (buttons1 & 0x04) != 0,
                right: (buttons1 & 0x02) != 0,
                sl: (buttons1 & 0x10) != 0,
                sr: (buttons1 & 0x20) != 0,
                l: (buttons2 & 0x40) != 0,
                zl: (buttons2 & 0x80) != 0,
                minus: (buttons2 & 0x01) != 0,
                capture: (buttons2 & 0x20) != 0,
                stick_click: (buttons2 & 0x08) != 0,
                stick_x,
                stick_y,
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

// Stub implementation when hidapi feature is disabled
#[cfg(not(feature = "hidapi"))]
pub struct HidApiJoyConManager;

#[cfg(not(feature = "hidapi"))]
impl HidApiJoyConManager {
    pub fn new() -> Result<Self, AppError> {
        Err(JoyConError::InitError("hidapi feature not enabled".to_string()).into())
    }
}
