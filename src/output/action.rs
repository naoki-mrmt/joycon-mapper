use crate::config::Modifier;

/// Output action types
#[derive(Debug, Clone, PartialEq)]
pub enum Action {
    /// Press/release a key
    KeyPress {
        key: Key,
        modifiers: Vec<Modifier>,
    },
    /// Mouse click
    MouseClick(MouseButton),
    /// Mouse movement
    MouseMove { dx: i32, dy: i32 },
    /// Scroll
    Scroll { dx: i32, dy: i32 },
    /// No action
    None,
}

/// Keyboard key
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum Key {
    // Letters
    A, B, C, D, E, F, G, H, I, J, K, L, M,
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
    // Numbers
    Num0, Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8, Num9,
    // Function keys
    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
    // Arrow keys
    UpArrow, DownArrow, LeftArrow, RightArrow,
    // Special keys
    Space, Enter, Tab, Escape, Backspace, Delete,
    Home, End, PageUp, PageDown,
    // Modifiers (for reference)
    Shift, Control, Alt, Command,
}

impl Key {
    /// Parse key from string
    pub fn from_str(s: &str) -> Option<Key> {
        match s.to_lowercase().as_str() {
            "a" => Some(Key::A), "b" => Some(Key::B), "c" => Some(Key::C),
            "d" => Some(Key::D), "e" => Some(Key::E), "f" => Some(Key::F),
            "g" => Some(Key::G), "h" => Some(Key::H), "i" => Some(Key::I),
            "j" => Some(Key::J), "k" => Some(Key::K), "l" => Some(Key::L),
            "m" => Some(Key::M), "n" => Some(Key::N), "o" => Some(Key::O),
            "p" => Some(Key::P), "q" => Some(Key::Q), "r" => Some(Key::R),
            "s" => Some(Key::S), "t" => Some(Key::T), "u" => Some(Key::U),
            "v" => Some(Key::V), "w" => Some(Key::W), "x" => Some(Key::X),
            "y" => Some(Key::Y), "z" => Some(Key::Z),
            "0" => Some(Key::Num0), "1" => Some(Key::Num1), "2" => Some(Key::Num2),
            "3" => Some(Key::Num3), "4" => Some(Key::Num4), "5" => Some(Key::Num5),
            "6" => Some(Key::Num6), "7" => Some(Key::Num7), "8" => Some(Key::Num8),
            "9" => Some(Key::Num9),
            "f1" => Some(Key::F1), "f2" => Some(Key::F2), "f3" => Some(Key::F3),
            "f4" => Some(Key::F4), "f5" => Some(Key::F5), "f6" => Some(Key::F6),
            "f7" => Some(Key::F7), "f8" => Some(Key::F8), "f9" => Some(Key::F9),
            "f10" => Some(Key::F10), "f11" => Some(Key::F11), "f12" => Some(Key::F12),
            "up" | "uparrow" => Some(Key::UpArrow),
            "down" | "downarrow" => Some(Key::DownArrow),
            "left" | "leftarrow" => Some(Key::LeftArrow),
            "right" | "rightarrow" => Some(Key::RightArrow),
            "space" => Some(Key::Space),
            "enter" | "return" => Some(Key::Enter),
            "tab" => Some(Key::Tab),
            "escape" | "esc" => Some(Key::Escape),
            "backspace" => Some(Key::Backspace),
            "delete" => Some(Key::Delete),
            "home" => Some(Key::Home),
            "end" => Some(Key::End),
            "pageup" => Some(Key::PageUp),
            "pagedown" => Some(Key::PageDown),
            "shift" => Some(Key::Shift),
            "control" | "ctrl" => Some(Key::Control),
            "alt" => Some(Key::Alt),
            "command" | "cmd" => Some(Key::Command),
            _ => None,
        }
    }
}

/// Mouse button
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MouseButton {
    Left,
    Right,
    Middle,
}

impl MouseButton {
    pub fn from_str(s: &str) -> Option<MouseButton> {
        match s.to_lowercase().as_str() {
            "left" | "leftclick" => Some(MouseButton::Left),
            "right" | "rightclick" => Some(MouseButton::Right),
            "middle" | "middleclick" => Some(MouseButton::Middle),
            _ => None,
        }
    }
}
