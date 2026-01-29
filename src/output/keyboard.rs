use enigo::{Enigo, Key as EnigoKey, Keyboard, Settings, Direction};
use crate::config::Modifier;
use crate::error::{AppError, OutputError};
use super::action::Key;

pub struct KeyboardOutput {
    enigo: Enigo,
}

impl KeyboardOutput {
    pub fn new() -> Result<Self, AppError> {
        let enigo = Enigo::new(&Settings::default())
            .map_err(|e| OutputError::KeyboardError(format!("Failed to initialize enigo: {:?}", e)))?;
        Ok(Self { enigo })
    }

    /// Press a key with optional modifiers
    pub fn press_key(&mut self, key: &Key, modifiers: &[Modifier]) -> Result<(), AppError> {
        // Press modifiers
        for modifier in modifiers {
            let _ = self.enigo.key(modifier_to_enigo(modifier), Direction::Press);
        }

        // Press and release key
        let enigo_key = key_to_enigo(key)
            .ok_or_else(|| OutputError::KeyboardError(format!("Unsupported key: {:?}", key)))?;
        let _ = self.enigo.key(enigo_key, Direction::Click);

        // Release modifiers
        for modifier in modifiers.iter().rev() {
            let _ = self.enigo.key(modifier_to_enigo(modifier), Direction::Release);
        }

        Ok(())
    }

    /// Press down a key
    pub fn key_down(&mut self, key: &Key) -> Result<(), AppError> {
        let enigo_key = key_to_enigo(key)
            .ok_or_else(|| OutputError::KeyboardError(format!("Unsupported key: {:?}", key)))?;
        let _ = self.enigo.key(enigo_key, Direction::Press);
        Ok(())
    }

    /// Release a key
    pub fn key_up(&mut self, key: &Key) -> Result<(), AppError> {
        let enigo_key = key_to_enigo(key)
            .ok_or_else(|| OutputError::KeyboardError(format!("Unsupported key: {:?}", key)))?;
        let _ = self.enigo.key(enigo_key, Direction::Release);
        Ok(())
    }
}

impl Default for KeyboardOutput {
    fn default() -> Self {
        Self::new().expect("Failed to create KeyboardOutput")
    }
}

fn modifier_to_enigo(modifier: &Modifier) -> EnigoKey {
    match modifier {
        Modifier::Cmd => EnigoKey::Meta,
        Modifier::Shift => EnigoKey::Shift,
        Modifier::Ctrl => EnigoKey::Control,
        Modifier::Alt | Modifier::Option => EnigoKey::Alt,
    }
}

fn key_to_enigo(key: &Key) -> Option<EnigoKey> {
    Some(match key {
        Key::A => EnigoKey::Unicode('a'),
        Key::B => EnigoKey::Unicode('b'),
        Key::C => EnigoKey::Unicode('c'),
        Key::D => EnigoKey::Unicode('d'),
        Key::E => EnigoKey::Unicode('e'),
        Key::F => EnigoKey::Unicode('f'),
        Key::G => EnigoKey::Unicode('g'),
        Key::H => EnigoKey::Unicode('h'),
        Key::I => EnigoKey::Unicode('i'),
        Key::J => EnigoKey::Unicode('j'),
        Key::K => EnigoKey::Unicode('k'),
        Key::L => EnigoKey::Unicode('l'),
        Key::M => EnigoKey::Unicode('m'),
        Key::N => EnigoKey::Unicode('n'),
        Key::O => EnigoKey::Unicode('o'),
        Key::P => EnigoKey::Unicode('p'),
        Key::Q => EnigoKey::Unicode('q'),
        Key::R => EnigoKey::Unicode('r'),
        Key::S => EnigoKey::Unicode('s'),
        Key::T => EnigoKey::Unicode('t'),
        Key::U => EnigoKey::Unicode('u'),
        Key::V => EnigoKey::Unicode('v'),
        Key::W => EnigoKey::Unicode('w'),
        Key::X => EnigoKey::Unicode('x'),
        Key::Y => EnigoKey::Unicode('y'),
        Key::Z => EnigoKey::Unicode('z'),
        Key::Num0 => EnigoKey::Unicode('0'),
        Key::Num1 => EnigoKey::Unicode('1'),
        Key::Num2 => EnigoKey::Unicode('2'),
        Key::Num3 => EnigoKey::Unicode('3'),
        Key::Num4 => EnigoKey::Unicode('4'),
        Key::Num5 => EnigoKey::Unicode('5'),
        Key::Num6 => EnigoKey::Unicode('6'),
        Key::Num7 => EnigoKey::Unicode('7'),
        Key::Num8 => EnigoKey::Unicode('8'),
        Key::Num9 => EnigoKey::Unicode('9'),
        Key::F1 => EnigoKey::F1,
        Key::F2 => EnigoKey::F2,
        Key::F3 => EnigoKey::F3,
        Key::F4 => EnigoKey::F4,
        Key::F5 => EnigoKey::F5,
        Key::F6 => EnigoKey::F6,
        Key::F7 => EnigoKey::F7,
        Key::F8 => EnigoKey::F8,
        Key::F9 => EnigoKey::F9,
        Key::F10 => EnigoKey::F10,
        Key::F11 => EnigoKey::F11,
        Key::F12 => EnigoKey::F12,
        Key::UpArrow => EnigoKey::UpArrow,
        Key::DownArrow => EnigoKey::DownArrow,
        Key::LeftArrow => EnigoKey::LeftArrow,
        Key::RightArrow => EnigoKey::RightArrow,
        Key::Space => EnigoKey::Space,
        Key::Enter => EnigoKey::Return,
        Key::Tab => EnigoKey::Tab,
        Key::Escape => EnigoKey::Escape,
        Key::Backspace => EnigoKey::Backspace,
        Key::Delete => EnigoKey::Delete,
        Key::Home => EnigoKey::Home,
        Key::End => EnigoKey::End,
        Key::PageUp => EnigoKey::PageUp,
        Key::PageDown => EnigoKey::PageDown,
        Key::Shift => EnigoKey::Shift,
        Key::Control => EnigoKey::Control,
        Key::Alt => EnigoKey::Alt,
        Key::Command => EnigoKey::Meta,
    })
}
