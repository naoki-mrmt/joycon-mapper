use std::collections::HashSet;
use crate::input::{JoyConButton, StickPosition};

/// Tracks the current state of the mapper
#[derive(Debug, Clone, Default)]
pub struct MapperState {
    /// Currently pressed buttons
    pub pressed_buttons: HashSet<JoyConButton>,
    /// Current stick position (after deadzone)
    pub stick_position: StickPosition,
    /// Currently active layer (if any)
    pub active_layer: Option<String>,
}

impl MapperState {
    pub fn new() -> Self {
        Self::default()
    }

    /// Update button state
    pub fn set_button_pressed(&mut self, button: JoyConButton, pressed: bool) {
        if pressed {
            self.pressed_buttons.insert(button);
        } else {
            self.pressed_buttons.remove(&button);
        }
        self.update_active_layer();
    }

    /// Check if button is pressed
    pub fn is_pressed(&self, button: JoyConButton) -> bool {
        self.pressed_buttons.contains(&button)
    }

    /// Update stick position
    pub fn set_stick_position(&mut self, position: StickPosition) {
        self.stick_position = position;
    }

    /// Update active layer based on held buttons
    fn update_active_layer(&mut self) {
        // Layer priority: zl_held > l_held
        if self.pressed_buttons.contains(&JoyConButton::Zl) {
            self.active_layer = Some("zl_held".to_string());
        } else if self.pressed_buttons.contains(&JoyConButton::L) {
            self.active_layer = Some("l_held".to_string());
        } else {
            self.active_layer = None;
        }
    }
}
