mod ipc;
mod service;
mod settings;
mod state;
mod telegram;

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::thread;

use clap::{Parser, Subcommand};

use crate::ipc::{Request, Response};
use crate::service::App;
use crate::settings::Settings;
use crate::state::Shared;
use crate::telegram::Telegram;

#[derive(Debug, Parser)]
#[command(name = "agent-telegram-bot", about = "Notify/ask bridge for agents via Telegram")]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Long-poll Telegram and serve the control socket (systemd default).
    Daemon,
    /// Fire-and-forget notice.
    Send {
        /// Role tag shown as [role] in the message.
        #[arg(long, default_value = "agent")]
        role: String,
        /// Message body. If omitted, read stdin.
        text: Option<String>,
    },
    /// Ask a question and block until a Telegram reply (or timeout).
    Ask {
        #[arg(long, default_value = "agent")]
        role: String,
        #[arg(long, default_value_t = 600)]
        timeout: u64,
        text: Option<String>,
    },
    /// Check the daemon control socket.
    Ping,
}

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    if let Err(err) = run() {
        eprintln!("{err}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let cli = Cli::parse();
    match cli.command.unwrap_or(Command::Daemon) {
        Command::Daemon => run_daemon(),
        Command::Send { role, text } => {
            let text = message_text(text)?;
            client_call(Request::Send {
                text,
                role: Some(role),
            })
        }
        Command::Ask {
            role,
            timeout,
            text,
        } => {
            let text = message_text(text)?;
            let response = raw_call(Request::Ask {
                text,
                role: Some(role),
                timeout_sec: timeout,
            })?;
            if !response.ok {
                return Err(response.error.unwrap_or_else(|| "ask failed".into()));
            }
            let answer = response.answer.unwrap_or_default();
            println!("{answer}");
            Ok(())
        }
        Command::Ping => client_call(Request::Ping),
    }
}

fn message_text(arg: Option<String>) -> Result<String, String> {
    if let Some(text) = arg {
        if text.trim().is_empty() {
            return Err("message text is empty".into());
        }
        return Ok(text);
    }
    let mut buf = String::new();
    std::io::Read::read_to_string(&mut std::io::stdin(), &mut buf)
        .map_err(|err| format!("reading stdin: {err}"))?;
    let text = buf.trim_end().to_string();
    if text.is_empty() {
        return Err("message text is empty".into());
    }
    Ok(text)
}

fn client_call(request: Request) -> Result<(), String> {
    let response = raw_call(request)?;
    if !response.ok {
        return Err(response.error.unwrap_or_else(|| "request failed".into()));
    }
    if let Some(answer) = response.answer {
        println!("{answer}");
    } else if let Some(message_id) = response.message_id {
        log::info!("sent message_id={message_id}");
    }
    Ok(())
}

fn raw_call(request: Request) -> Result<Response, String> {
    let socket = socket_path()?;
    ipc::call(&socket, &request)
}

fn run_daemon() -> Result<(), String> {
    let token_path = env_var("AGENT_TELEGRAM_BOT_TOKEN_FILE")?;
    let token = std::fs::read_to_string(&token_path)
        .map_err(|err| format!("reading telegram token: {err}"))?;
    let token = token.trim();
    if token.is_empty() || token == "REPLACE_ME" {
        return Err("agent_telegram_bot_token is missing (set sops secret)".into());
    }
    let settings = Settings::load(Path::new(&env_var("AGENT_TELEGRAM_BOT_SETTINGS")?))?;
    let state_dir = env_var("STATE_DIRECTORY")?;
    let state = Shared::load(Path::new(&state_dir))?;
    let socket = socket_path()?;
    let app = Arc::new(App::new(settings, Telegram::new(token)));

    let app_ipc = Arc::clone(&app);
    let state_ipc = Arc::clone(&state);
    thread::spawn(move || {
        if let Err(err) = ipc::listen(&socket, app_ipc, state_ipc) {
            log::error!("ipc listener exited: {err}");
            std::process::exit(1);
        }
    });

    app.run_poll(state)
}

fn socket_path() -> Result<PathBuf, String> {
    if let Ok(path) = std::env::var("AGENT_TELEGRAM_BOT_SOCKET") {
        return Ok(PathBuf::from(path));
    }
    if let Ok(state) = std::env::var("STATE_DIRECTORY") {
        return Ok(PathBuf::from(state).join("agent-telegram-bot.sock"));
    }
    let home = std::env::var("HOME").map_err(|_| String::from("HOME is not set"))?;
    let state_home =
        std::env::var("XDG_STATE_HOME").unwrap_or_else(|_| format!("{home}/.local/state"));
    Ok(PathBuf::from(state_home).join("agent-telegram-bot/agent-telegram-bot.sock"))
}

fn env_var(key: &str) -> Result<String, String> {
    std::env::var(key).map_err(|_| format!("{key} is not set"))
}
