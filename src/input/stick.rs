/// Stick position (normalized -1.0 to 1.0)
#[derive(Debug, Clone, Copy, Default)]
pub struct StickPosition {
    pub x: f32,
    pub y: f32,
}

impl StickPosition {
    pub fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }

    /// Apply deadzone
    pub fn with_deadzone(self, deadzone: f32) -> Self {
        let magnitude = (self.x * self.x + self.y * self.y).sqrt();
        if magnitude < deadzone {
            Self::default()
        } else {
            // Scale to full range after deadzone
            let scale = (magnitude - deadzone) / (1.0 - deadzone) / magnitude;
            Self {
                x: self.x * scale,
                y: self.y * scale,
            }
        }
    }

    /// Check if stick is in neutral position
    pub fn is_neutral(&self) -> bool {
        self.x == 0.0 && self.y == 0.0
    }

    /// Get magnitude (0.0 to 1.0)
    pub fn magnitude(&self) -> f32 {
        (self.x * self.x + self.y * self.y).sqrt().min(1.0)
    }
}
