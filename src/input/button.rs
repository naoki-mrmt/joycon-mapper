use serde::{Deserialize, Serialize};
use std::fmt;

/// Joy-Con Left buttons
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum JoyConButton {
    Up,
    Down,
    Left,
    Right,
    L,
    Zl,
    Minus,
    Capture,
    StickClick,
    Sl,
    Sr,
}

impl JoyConButton {
    /// Get all buttons
    pub fn all() -> &'static [JoyConButton] {
        &[
            JoyConButton::Up,
            JoyConButton::Down,
            JoyConButton::Left,
            JoyConButton::Right,
            JoyConButton::L,
            JoyConButton::Zl,
            JoyConButton::Minus,
            JoyConButton::Capture,
            JoyConButton::StickClick,
            JoyConButton::Sl,
            JoyConButton::Sr,
        ]
    }

    /// Get config key name
    pub fn config_key(&self) -> &'static str {
        match self {
            JoyConButton::Up => "up",
            JoyConButton::Down => "down",
            JoyConButton::Left => "left",
            JoyConButton::Right => "right",
            JoyConButton::L => "l",
            JoyConButton::Zl => "zl",
            JoyConButton::Minus => "minus",
            JoyConButton::Capture => "capture",
            JoyConButton::StickClick => "stick_click",
            JoyConButton::Sl => "sl",
            JoyConButton::Sr => "sr",
        }
    }

    /// Parse from config key
    pub fn from_config_key(key: &str) -> Option<JoyConButton> {
        match key.to_lowercase().as_str() {
            "up" => Some(JoyConButton::Up),
            "down" => Some(JoyConButton::Down),
            "left" => Some(JoyConButton::Left),
            "right" => Some(JoyConButton::Right),
            "l" => Some(JoyConButton::L),
            "zl" => Some(JoyConButton::Zl),
            "minus" => Some(JoyConButton::Minus),
            "capture" => Some(JoyConButton::Capture),
            "stick_click" => Some(JoyConButton::StickClick),
            "sl" => Some(JoyConButton::Sl),
            "sr" => Some(JoyConButton::Sr),
            _ => None,
        }
    }
}

impl fmt::Display for JoyConButton {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.config_key())
    }
}

/// Button state
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ButtonState {
    Pressed,
    Released,
}

/// Button event
#[derive(Debug, Clone, Copy)]
pub struct ButtonEvent {
    pub button: JoyConButton,
    pub state: ButtonState,
}

impl ButtonEvent {
    pub fn pressed(button: JoyConButton) -> Self {
        Self { button, state: ButtonState::Pressed }
    }

    pub fn released(button: JoyConButton) -> Self {
        Self { button, state: ButtonState::Released }
    }

    pub fn is_pressed(&self) -> bool {
        self.state == ButtonState::Pressed
    }
}
