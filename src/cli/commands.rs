use clap::{Parser, Subcommand};
use std::path::PathBuf;

/// Joy-Con Left to keyboard/mouse mapper for macOS
#[derive(Parser, Debug)]
#[command(name = "joycon-mapper")]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,

    /// Enable verbose output
    #[arg(short, long, global = true)]
    pub verbose: bool,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// List connected Joy-Con devices
    List,

    /// Start the key mapping service
    Run {
        /// Path to config file
        #[arg(short, long)]
        config: Option<PathBuf>,

        /// Test mode - log actions without sending keys
        #[arg(long)]
        dry_run: bool,
    },

    /// Validate a configuration file
    Validate {
        /// Path to config file to validate
        #[arg(short, long)]
        file: Option<PathBuf>,
    },

    /// Generate a default configuration file
    Init {
        /// Output path for config file
        #[arg(short, long)]
        output: Option<PathBuf>,
    },

    /// Monitor Joy-Con input in real-time
    Monitor {
        /// Show raw HID data
        #[arg(long)]
        raw: bool,

        /// Use hidapi instead of IOHIDManager (may work when gamecontrollerd blocks access)
        #[arg(long)]
        hidapi: bool,
    },
}
