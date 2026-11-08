mod action;
mod commands;
mod gws;
mod interpret;
mod proc;
mod route;
mod service;
mod settings;
mod shortcuts;
mod state;
mod telegram;

use std::path::Path;

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    if let Err(err) = run() {
        log::error!("{err}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let token_path = env_var("TELEGRAM_BOT_TOKEN_FILE")?;
    let token = std::fs::read_to_string(&token_path)
        .map_err(|err| format!("reading telegram token: {err}"))?;
    let token = token.trim();
    if token.is_empty() || token == "REPLACE_ME" {
        return Err("telegram_bot_token is missing".into());
    }
    let settings = settings::Settings::load(Path::new(&env_var("TELEGRAM_BOT_SETTINGS")?))?;
    let tz = commands::timezone(&settings.timezone)?;
    let state = state::State::load(Path::new(&env_var("STATE_DIRECTORY")?))?;
    let interpreter = interpret::CursorCliInterpreter::new(
        env_var("CURSOR_AGENT")?.into(),
        settings.workspace.clone().into(),
    );
    let mut service = service::Service::new(
        settings,
        tz,
        telegram::Telegram::new(token),
        state,
        env_var("GWS")?.into(),
        env_var("EXPENSES_SPREADSHEET")?.into(),
        interpreter,
    );
    service.run()
}

fn env_var(key: &str) -> Result<String, String> {
    std::env::var(key).map_err(|_| format!("{key} is not set"))
}
