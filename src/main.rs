use std::path::PathBuf;
use std::thread;
use std::time::Duration;
use anyhow::Result;
use clap::Parser;
use log::{info, warn, error};

use joycon_mapper::cli::{Cli, Commands};
use joycon_mapper::config;
use joycon_mapper::input::{JoyConManager, InputEvent};
use joycon_mapper::mapper::MappingEngine;

fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize logger
    let log_level = if cli.verbose { "debug" } else { "info" };
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or(log_level))
        .init();

    match cli.command {
        Commands::List => cmd_list(),
        Commands::Run { config: config_path, dry_run } => cmd_run(config_path, dry_run),
        Commands::Validate { file } => cmd_validate(file),
        Commands::Init { output } => cmd_init(output),
        Commands::Monitor { raw, hidapi } => cmd_monitor(raw, hidapi),
    }
}

/// List connected Joy-Con devices
fn cmd_list() -> Result<()> {
    info!("Scanning for Joy-Con devices...");

    let manager = JoyConManager::new()?;
    let devices = manager.list_devices()?;

    if devices.is_empty() {
        println!("No Joy-Con devices found.");
        println!("\nMake sure your Joy-Con is:");
        println!("  1. In pairing mode (hold SYNC button)");
        println!("  2. Paired via System Settings > Bluetooth");
        return Ok(());
    }

    println!("Found {} device(s):", devices.len());
    for (i, device) in devices.iter().enumerate() {
        println!("  {}. {} - {}", i + 1, device.device_type, device.name);
        if let Some(serial) = &device.serial {
            println!("     Serial: {}", serial);
        }
    }

    Ok(())
}

/// Run the mapping service
fn cmd_run(config_path: Option<PathBuf>, dry_run: bool) -> Result<()> {
    // Load configuration
    let config = config::load_config_or_default(config_path.as_deref())?;

    if dry_run {
        info!("Running in DRY-RUN mode - no actual input will be sent");
    }

    info!("Connecting to Joy-Con...");

    let mut manager = JoyConManager::new()?;
    let mut connection = manager.connect_left()?;

    info!("Connected! Starting mapping...");
    info!("Press Ctrl+C to exit");

    let mut engine = MappingEngine::new(config, dry_run)?;

    // Main loop
    loop {
        match connection.poll() {
            Ok(events) => {
                for event in events {
                    if let Err(e) = engine.process_event(event) {
                        warn!("Error processing event: {}", e);
                    }
                }
            }
            Err(e) => {
                error!("Error reading from Joy-Con: {}", e);
                // Try to reconnect
                info!("Attempting to reconnect...");
                thread::sleep(Duration::from_secs(1));
                match manager.connect_left() {
                    Ok(new_conn) => {
                        connection = new_conn;
                        info!("Reconnected!");
                    }
                    Err(e) => {
                        error!("Failed to reconnect: {}", e);
                        thread::sleep(Duration::from_secs(2));
                    }
                }
            }
        }

        // Small delay to prevent CPU spinning
        thread::sleep(Duration::from_millis(8)); // ~120Hz polling
    }
}

/// Validate configuration file
fn cmd_validate(file: Option<PathBuf>) -> Result<()> {
    let path = file.unwrap_or_else(config::default_config_path);

    info!("Validating config: {}", path.display());

    match config::load_config(&path) {
        Ok(config) => {
            println!("Configuration is valid!");
            println!("\nSummary:");
            println!("  Stick deadzone: {}", config.mapping.stick_deadzone);
            println!("  Stick mode: {:?}", config.mapping.stick.mode);
            println!("  Button mappings: {}", config.mapping.buttons.len());
            println!("  Layers: {}", config.mapping.layers.len());
            Ok(())
        }
        Err(e) => {
            eprintln!("Configuration error: {}", e);
            std::process::exit(1);
        }
    }
}

/// Generate default configuration file
fn cmd_init(output: Option<PathBuf>) -> Result<()> {
    let path = output.unwrap_or_else(config::default_config_path);

    if path.exists() {
        eprintln!("Config file already exists: {}", path.display());
        eprintln!("Use a different path with --output or delete the existing file.");
        std::process::exit(1);
    }

    let content = config::generate_default_config();
    config::save_config(&path, &content)?;

    println!("Created default config: {}", path.display());
    println!("\nEdit this file to customize your button mappings.");

    Ok(())
}

/// Monitor Joy-Con input
fn cmd_monitor(raw: bool, use_hidapi: bool) -> Result<()> {
    info!("Connecting to Joy-Con for monitoring...");

    #[cfg(feature = "hidapi")]
    if use_hidapi {
        return cmd_monitor_hidapi(raw);
    }

    #[cfg(not(feature = "hidapi"))]
    if use_hidapi {
        error!("hidapi feature is not enabled. Rebuild with: cargo build --features hidapi");
        std::process::exit(1);
    }

    let mut manager = JoyConManager::new()?;
    let mut connection = manager.connect_left()?;

    info!("Connected! Monitoring input... Press Ctrl+C to exit");
    println!();

    loop {
        match connection.poll() {
            Ok(events) => {
                for event in events {
                    match &event {
                        InputEvent::Button(btn_event) => {
                            let state = if btn_event.is_pressed() { "PRESSED" } else { "RELEASED" };
                            println!("Button: {:?} - {}", btn_event.button, state);
                        }
                        InputEvent::Stick(pos) => {
                            if !pos.is_neutral() || raw {
                                println!("Stick: x={:.2}, y={:.2}", pos.x, pos.y);
                            }
                        }
                    }
                }
            }
            Err(e) => {
                error!("Error: {}", e);
                thread::sleep(Duration::from_secs(1));
            }
        }

        thread::sleep(Duration::from_millis(16)); // ~60Hz for monitoring
    }
}

/// Monitor Joy-Con input using hidapi
#[cfg(feature = "hidapi")]
fn cmd_monitor_hidapi(raw: bool) -> Result<()> {
    use joycon_mapper::input::HidApiJoyConManager;

    info!("Using hidapi backend...");

    let manager = HidApiJoyConManager::new()?;
    let mut connection = manager.connect_left()?;

    info!("Connected via hidapi! Monitoring input... Press Ctrl+C to exit");
    println!();

    loop {
        match connection.poll() {
            Ok(events) => {
                for event in events {
                    match &event {
                        InputEvent::Button(btn_event) => {
                            let state = if btn_event.is_pressed() { "PRESSED" } else { "RELEASED" };
                            println!("Button: {:?} - {}", btn_event.button, state);
                        }
                        InputEvent::Stick(pos) => {
                            if !pos.is_neutral() || raw {
                                println!("Stick: x={:.2}, y={:.2}", pos.x, pos.y);
                            }
                        }
                    }
                }
            }
            Err(e) => {
                error!("Error: {}", e);
                thread::sleep(Duration::from_secs(1));
            }
        }

        thread::sleep(Duration::from_millis(16)); // ~60Hz for monitoring
    }
}
