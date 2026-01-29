use enigo::{Enigo, Button as EnigoButton, Mouse, Settings, Direction, Coordinate, Axis};
use crate::error::{AppError, OutputError};
use super::action::MouseButton;

pub struct MouseOutput {
    enigo: Enigo,
}

impl MouseOutput {
    pub fn new() -> Result<Self, AppError> {
        let enigo = Enigo::new(&Settings::default())
            .map_err(|e| OutputError::MouseError(format!("Failed to initialize enigo: {:?}", e)))?;
        Ok(Self { enigo })
    }

    /// Move mouse relative to current position
    pub fn move_relative(&mut self, dx: i32, dy: i32) -> Result<(), AppError> {
        let _ = self.enigo.move_mouse(dx, dy, Coordinate::Rel);
        Ok(())
    }

    /// Click mouse button
    pub fn click(&mut self, button: MouseButton) -> Result<(), AppError> {
        let _ = self.enigo.button(button_to_enigo(button), Direction::Click);
        Ok(())
    }

    /// Press mouse button down
    pub fn button_down(&mut self, button: MouseButton) -> Result<(), AppError> {
        let _ = self.enigo.button(button_to_enigo(button), Direction::Press);
        Ok(())
    }

    /// Release mouse button
    pub fn button_up(&mut self, button: MouseButton) -> Result<(), AppError> {
        let _ = self.enigo.button(button_to_enigo(button), Direction::Release);
        Ok(())
    }

    /// Scroll
    pub fn scroll(&mut self, dx: i32, dy: i32) -> Result<(), AppError> {
        if dy != 0 {
            let _ = self.enigo.scroll(dy, Axis::Vertical);
        }
        if dx != 0 {
            let _ = self.enigo.scroll(dx, Axis::Horizontal);
        }
        Ok(())
    }
}

impl Default for MouseOutput {
    fn default() -> Self {
        Self::new().expect("Failed to create MouseOutput")
    }
}

fn button_to_enigo(button: MouseButton) -> EnigoButton {
    match button {
        MouseButton::Left => EnigoButton::Left,
        MouseButton::Right => EnigoButton::Right,
        MouseButton::Middle => EnigoButton::Middle,
    }
}
