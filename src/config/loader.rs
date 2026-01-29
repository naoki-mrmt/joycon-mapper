use std::path::{Path, PathBuf};
use std::fs;
use crate::error::{AppError, ConfigError};
use super::schema::Config;

/// Default config file name
pub const DEFAULT_CONFIG_NAME: &str = "config.toml";

/// Get default config directory
pub fn default_config_dir() -> PathBuf {
    dirs::config_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("joycon-mapper")
}

/// Get default config file path
pub fn default_config_path() -> PathBuf {
    default_config_dir().join(DEFAULT_CONFIG_NAME)
}

/// Load configuration from file
pub fn load_config(path: &Path) -> Result<Config, AppError> {
    if !path.exists() {
        return Err(ConfigError::NotFound(path.to_path_buf()).into());
    }

    let content = fs::read_to_string(path)
        .map_err(ConfigError::IoError)?;

    let config: Config = toml::from_str(&content)
        .map_err(ConfigError::TomlError)?;

    validate_config(&config)?;

    Ok(config)
}

/// Load configuration from default location or specified path
pub fn load_config_or_default(path: Option<&Path>) -> Result<Config, AppError> {
    match path {
        Some(p) => load_config(p),
        None => {
            let default_path = default_config_path();
            if default_path.exists() {
                load_config(&default_path)
            } else {
                // Return default config if no config file exists
                Ok(Config::default())
            }
        }
    }
}

/// Validate configuration
pub fn validate_config(config: &Config) -> Result<(), AppError> {
    // Validate deadzone
    if config.mapping.stick_deadzone < 0.0 || config.mapping.stick_deadzone > 1.0 {
        return Err(ConfigError::ValidationError(
            format!("stick_deadzone must be between 0.0 and 1.0, got {}", config.mapping.stick_deadzone)
        ).into());
    }

    // Validate mouse sensitivity
    if config.mapping.stick.mouse.sensitivity <= 0.0 {
        return Err(ConfigError::ValidationError(
            format!("mouse sensitivity must be positive, got {}", config.mapping.stick.mouse.sensitivity)
        ).into());
    }

    // Validate scroll speed
    if config.mapping.stick.scroll.speed <= 0.0 {
        return Err(ConfigError::ValidationError(
            format!("scroll speed must be positive, got {}", config.mapping.stick.scroll.speed)
        ).into());
    }

    Ok(())
}

/// Generate default configuration as TOML string
pub fn generate_default_config() -> String {
    r#"# Joy-Con Mapper Configuration

[device]
auto_detect = true

[mapping]
stick_deadzone = 0.15

[mapping.buttons]
up = "key:UpArrow"
down = "key:DownArrow"
left = "key:LeftArrow"
right = "key:RightArrow"
l = "key:Space"
zl = "mouse:LeftClick"
minus = "key:Escape"
capture = { action = "key:S", modifiers = ["Cmd", "Shift"] }
stick_click = "key:Enter"

[mapping.stick]
mode = "mouse"

[mapping.stick.mouse]
sensitivity = 5.0

[mapping.stick.scroll]
speed = 1.0

# Layer activated when ZL is held
[mapping.layers.zl_held]
up = { action = "scroll:up", amount = 3 }
down = { action = "scroll:down", amount = 3 }
"#.to_string()
}

/// Save configuration to file
pub fn save_config(path: &Path, content: &str) -> Result<(), AppError> {
    // Create parent directories if they don't exist
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(ConfigError::IoError)?;
    }

    fs::write(path, content)
        .map_err(ConfigError::IoError)?;

    Ok(())
}
