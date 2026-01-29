use crate::config::{Config, ButtonMapping, StickMode, Modifier};
use crate::error::{AppError, MappingError};
use crate::input::{JoyConButton, ButtonEvent, StickPosition, InputEvent};
use crate::output::{Action, Key, MouseButton, KeyboardOutput, MouseOutput};
use super::state::MapperState;
use super::transform::{self, ActionType};
use log::{debug, info};

/// Main mapping engine
pub struct MappingEngine {
    config: Config,
    state: MapperState,
    keyboard: Option<KeyboardOutput>,
    mouse: Option<MouseOutput>,
    dry_run: bool,
}

impl MappingEngine {
    /// Create new mapping engine
    pub fn new(config: Config, dry_run: bool) -> Result<Self, AppError> {
        let keyboard = if dry_run { None } else { Some(KeyboardOutput::new()?) };
        let mouse = if dry_run { None } else { Some(MouseOutput::new()?) };

        Ok(Self {
            config,
            state: MapperState::new(),
            keyboard,
            mouse,
            dry_run,
        })
    }

    /// Process an input event
    pub fn process_event(&mut self, event: InputEvent) -> Result<(), AppError> {
        match event {
            InputEvent::Button(button_event) => self.process_button(button_event),
            InputEvent::Stick(position) => self.process_stick(position),
        }
    }

    /// Process button event
    fn process_button(&mut self, event: ButtonEvent) -> Result<(), AppError> {
        let button = event.button;
        let pressed = event.is_pressed();

        // Update state
        self.state.set_button_pressed(button, pressed);

        // Get mapping for this button
        let mapping = self.get_button_mapping(&button);

        if let Some(mapping) = mapping {
            let action = self.parse_button_mapping(&mapping)?;

            if pressed {
                self.execute_action_press(&action)?;
            } else {
                self.execute_action_release(&action)?;
            }
        }

        Ok(())
    }

    /// Get button mapping considering active layer
    fn get_button_mapping(&self, button: &JoyConButton) -> Option<ButtonMapping> {
        let key = button.config_key();

        // Check active layer first
        if let Some(layer_name) = &self.state.active_layer {
            if let Some(layer) = self.config.mapping.layers.get(layer_name) {
                if let Some(mapping) = layer.buttons.get(key) {
                    return Some(mapping.clone());
                }
            }
        }

        // Fall back to default mapping
        self.config.mapping.buttons.get(key).cloned()
    }

    /// Parse button mapping into action
    fn parse_button_mapping(&self, mapping: &ButtonMapping) -> Result<Action, AppError> {
        let (action_str, modifiers) = match mapping {
            ButtonMapping::Simple(s) => (s.as_str(), vec![]),
            ButtonMapping::Complex { action, modifiers } => {
                let mods: Vec<Modifier> = modifiers.iter()
                    .filter_map(|s| parse_modifier(s))
                    .collect();
                (action.as_str(), mods)
            }
        };

        let (action_type, value) = transform::parse_action_string(action_str)
            .ok_or_else(|| MappingError::InvalidAction(action_str.to_string()))?;

        match action_type {
            ActionType::Key => {
                let key = Key::from_str(&value)
                    .ok_or_else(|| MappingError::InvalidKey(value.clone()))?;
                Ok(Action::KeyPress { key, modifiers })
            }
            ActionType::Mouse => {
                let button = MouseButton::from_str(&value)
                    .ok_or_else(|| MappingError::InvalidAction(format!("Invalid mouse action: {}", value)))?;
                Ok(Action::MouseClick(button))
            }
            ActionType::Scroll => {
                let (dx, dy) = match value.to_lowercase().as_str() {
                    "up" => (0, 1),
                    "down" => (0, -1),
                    "left" => (-1, 0),
                    "right" => (1, 0),
                    _ => return Err(MappingError::InvalidAction(format!("Invalid scroll direction: {}", value)).into()),
                };
                Ok(Action::Scroll { dx, dy })
            }
        }
    }

    /// Execute action on press
    fn execute_action_press(&mut self, action: &Action) -> Result<(), AppError> {
        if self.dry_run {
            info!("[DRY-RUN] Press: {:?}", action);
            return Ok(());
        }

        match action {
            Action::KeyPress { key, modifiers } => {
                if let Some(kb) = &mut self.keyboard {
                    kb.press_key(key, modifiers)?;
                }
            }
            Action::MouseClick(button) => {
                if let Some(mouse) = &mut self.mouse {
                    mouse.button_down(*button)?;
                }
            }
            Action::Scroll { dx, dy } => {
                if let Some(mouse) = &mut self.mouse {
                    mouse.scroll(*dx, *dy)?;
                }
            }
            Action::MouseMove { .. } | Action::None => {}
        }

        Ok(())
    }

    /// Execute action on release
    fn execute_action_release(&mut self, action: &Action) -> Result<(), AppError> {
        if self.dry_run {
            debug!("[DRY-RUN] Release: {:?}", action);
            return Ok(());
        }

        match action {
            Action::MouseClick(button) => {
                if let Some(mouse) = &mut self.mouse {
                    mouse.button_up(*button)?;
                }
            }
            _ => {}
        }

        Ok(())
    }

    /// Process stick movement
    fn process_stick(&mut self, position: StickPosition) -> Result<(), AppError> {
        let position = transform::apply_stick_deadzone(position, self.config.mapping.stick_deadzone);
        self.state.set_stick_position(position);

        if position.is_neutral() {
            return Ok(());
        }

        match self.config.mapping.stick.mode {
            StickMode::Mouse => {
                let (dx, dy) = transform::stick_to_mouse_delta(
                    &position,
                    self.config.mapping.stick.mouse.sensitivity
                );

                if self.dry_run {
                    debug!("[DRY-RUN] Mouse move: ({}, {})", dx, dy);
                } else if let Some(mouse) = &mut self.mouse {
                    mouse.move_relative(dx, dy)?;
                }
            }
            StickMode::Scroll => {
                let (dx, dy) = transform::stick_to_scroll_delta(
                    &position,
                    self.config.mapping.stick.scroll.speed
                );

                if self.dry_run {
                    debug!("[DRY-RUN] Scroll: ({}, {})", dx, dy);
                } else if let Some(mouse) = &mut self.mouse {
                    mouse.scroll(dx, dy)?;
                }
            }
            StickMode::Keys | StickMode::Disabled => {}
        }

        Ok(())
    }
}

fn parse_modifier(s: &str) -> Option<Modifier> {
    match s.to_lowercase().as_str() {
        "cmd" | "command" => Some(Modifier::Cmd),
        "shift" => Some(Modifier::Shift),
        "ctrl" | "control" => Some(Modifier::Ctrl),
        "alt" | "option" => Some(Modifier::Alt),
        _ => None,
    }
}
