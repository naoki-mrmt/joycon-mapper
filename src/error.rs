use std::path::PathBuf;
use thiserror::Error;

/// Joy-Con communication errors
#[derive(Error, Debug)]
pub enum JoyConError {
    #[error("No Joy-Con device found")]
    NotFound,

    #[error("Failed to connect to Joy-Con: {0}")]
    ConnectionFailed(String),

    #[error("Joy-Con disconnected")]
    Disconnected,

    #[error("Failed to read input: {0}")]
    ReadError(String),

    #[error("Failed to initialize Joy-Con: {0}")]
    InitError(String),
}

/// Configuration errors
#[derive(Error, Debug)]
pub enum ConfigError {
    #[error("Config file not found: {0}")]
    NotFound(PathBuf),

    #[error("Failed to parse config: {0}")]
    ParseError(String),

    #[error("Invalid config value: {0}")]
    ValidationError(String),

    #[error("I/O error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("TOML parse error: {0}")]
    TomlError(#[from] toml::de::Error),
}

/// Mapping execution errors
#[derive(Error, Debug)]
pub enum MappingError {
    #[error("Invalid action: {0}")]
    InvalidAction(String),

    #[error("Invalid key: {0}")]
    InvalidKey(String),

    #[error("Invalid button: {0}")]
    InvalidButton(String),
}

/// Output errors
#[derive(Error, Debug)]
pub enum OutputError {
    #[error("Keyboard error: {0}")]
    KeyboardError(String),

    #[error("Mouse error: {0}")]
    MouseError(String),
}

/// Top-level application error
#[derive(Error, Debug)]
pub enum AppError {
    #[error("Joy-Con error: {0}")]
    JoyCon(#[from] JoyConError),

    #[error("Config error: {0}")]
    Config(#[from] ConfigError),

    #[error("Mapping error: {0}")]
    Mapping(#[from] MappingError),

    #[error("Output error: {0}")]
    Output(#[from] OutputError),
}

pub type Result<T> = std::result::Result<T, AppError>;
