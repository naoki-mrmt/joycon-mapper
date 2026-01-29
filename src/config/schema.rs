use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Root configuration
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Config {
    #[serde(default)]
    pub device: DeviceConfig,
    #[serde(default)]
    pub mapping: MappingConfig,
}

/// Device settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceConfig {
    #[serde(default = "default_auto_detect")]
    pub auto_detect: bool,
}

impl Default for DeviceConfig {
    fn default() -> Self {
        Self { auto_detect: true }
    }
}

fn default_auto_detect() -> bool { true }

/// Mapping configuration
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct MappingConfig {
    #[serde(default = "default_deadzone")]
    pub stick_deadzone: f32,
    #[serde(default)]
    pub buttons: HashMap<String, ButtonMapping>,
    #[serde(default)]
    pub stick: StickConfig,
    #[serde(default)]
    pub layers: HashMap<String, LayerConfig>,
}

fn default_deadzone() -> f32 { 0.15 }

/// Button mapping - can be simple string or complex object
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum ButtonMapping {
    Simple(String),
    Complex {
        action: String,
        #[serde(default)]
        modifiers: Vec<String>,
    },
}

/// Stick configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StickConfig {
    #[serde(default = "default_stick_mode")]
    pub mode: StickMode,
    #[serde(default)]
    pub mouse: MouseStickConfig,
    #[serde(default)]
    pub scroll: ScrollStickConfig,
}

impl Default for StickConfig {
    fn default() -> Self {
        Self {
            mode: StickMode::Mouse,
            mouse: MouseStickConfig::default(),
            scroll: ScrollStickConfig::default(),
        }
    }
}

fn default_stick_mode() -> StickMode { StickMode::Mouse }

/// Stick mode
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum StickMode {
    #[default]
    Mouse,
    Scroll,
    Keys,
    Disabled,
}

/// Mouse stick settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MouseStickConfig {
    #[serde(default = "default_sensitivity")]
    pub sensitivity: f32,
}

impl Default for MouseStickConfig {
    fn default() -> Self {
        Self { sensitivity: 5.0 }
    }
}

fn default_sensitivity() -> f32 { 5.0 }

/// Scroll stick settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScrollStickConfig {
    #[serde(default = "default_scroll_speed")]
    pub speed: f32,
}

impl Default for ScrollStickConfig {
    fn default() -> Self {
        Self { speed: 1.0 }
    }
}

fn default_scroll_speed() -> f32 { 1.0 }

/// Layer configuration (activated when specific button is held)
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LayerConfig {
    #[serde(flatten)]
    pub buttons: HashMap<String, ButtonMapping>,
}

/// Modifier keys
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Modifier {
    Cmd,
    Shift,
    Ctrl,
    Alt,
    #[serde(alias = "Option")]
    Option,
}
