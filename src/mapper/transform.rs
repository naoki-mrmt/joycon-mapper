use crate::input::StickPosition;

/// Apply transformations to stick input
pub fn apply_stick_deadzone(position: StickPosition, deadzone: f32) -> StickPosition {
    position.with_deadzone(deadzone)
}

/// Calculate mouse movement from stick position
pub fn stick_to_mouse_delta(position: &StickPosition, sensitivity: f32) -> (i32, i32) {
    let dx = (position.x * sensitivity * 10.0) as i32;
    let dy = (-position.y * sensitivity * 10.0) as i32; // Invert Y for screen coords
    (dx, dy)
}

/// Calculate scroll amount from stick position
pub fn stick_to_scroll_delta(position: &StickPosition, speed: f32) -> (i32, i32) {
    let dx = (position.x * speed * 3.0) as i32;
    let dy = (position.y * speed * 3.0) as i32;
    (dx, dy)
}

/// Parse action string into components
/// Format: "action_type:action_value" e.g., "key:Space", "mouse:LeftClick", "scroll:up"
pub fn parse_action_string(action: &str) -> Option<(ActionType, String)> {
    let parts: Vec<&str> = action.splitn(2, ':').collect();
    if parts.len() != 2 {
        return None;
    }

    let action_type = match parts[0].to_lowercase().as_str() {
        "key" => ActionType::Key,
        "mouse" => ActionType::Mouse,
        "scroll" => ActionType::Scroll,
        _ => return None,
    };

    Some((action_type, parts[1].to_string()))
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ActionType {
    Key,
    Mouse,
    Scroll,
}
