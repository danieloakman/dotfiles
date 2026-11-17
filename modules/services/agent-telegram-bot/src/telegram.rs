use std::time::Duration;

use frankenstein::client_ureq::Bot;
use frankenstein::methods::{GetUpdatesParams, SendMessageParams};
use frankenstein::types::AllowedUpdate;
use frankenstein::updates::Update;
use frankenstein::TelegramApi;

const TEXT_LIMIT: usize = 3500;
const HTTP_TIMEOUT: Duration = Duration::from_secs(70);

pub struct Telegram {
    bot: Bot,
}

impl Telegram {
    pub fn new(token: &str) -> Self {
        let agent = ureq::Agent::new_with_config(
            ureq::config::Config::builder()
                .http_status_as_error(false)
                .timeout_global(Some(HTTP_TIMEOUT))
                .build(),
        );
        Self {
            bot: Bot::builder()
                .api_url(format!("https://api.telegram.org/bot{token}"))
                .request_agent(agent)
                .build(),
        }
    }

    pub fn updates(&self, offset: Option<i64>) -> Result<Vec<Update>, String> {
        let params = GetUpdatesParams::builder()
            .maybe_offset(offset)
            .timeout(50u32)
            .allowed_updates(vec![AllowedUpdate::Message])
            .build();
        self.bot
            .get_updates(&params)
            .map(|response| response.result)
            .map_err(|err| err.to_string())
    }

    pub fn send(&self, chat_id: i64, text: &str) -> Result<i32, String> {
        let params = SendMessageParams::builder()
            .chat_id(chat_id)
            .text(clip(text))
            .build();
        self.bot
            .send_message(&params)
            .map(|response| response.result.message_id)
            .map_err(|err| err.to_string())
    }
}

fn clip(text: &str) -> String {
    let mut clipped: String = text.chars().take(TEXT_LIMIT).collect();
    if text.chars().count() > TEXT_LIMIT {
        clipped.push('…');
    }
    clipped
}
