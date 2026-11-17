use std::time::Duration;

use frankenstein::client_ureq::Bot;
use frankenstein::inline_mode::{
    InlineQueryResult, InlineQueryResultArticle, InputTextMessageContent,
};
use frankenstein::methods::{
    AnswerCallbackQueryParams, AnswerGuestQueryParams, DeleteMyCommandsParams,
    EditMessageTextParams, GetMyCommandsParams, GetUpdatesParams, SendMessageParams,
    SetMyCommandsParams,
};
use frankenstein::types::{
    AllowedUpdate, BotCommand, InlineKeyboardButton, InlineKeyboardMarkup, ReplyMarkup,
};
use frankenstein::updates::Update;
use frankenstein::TelegramApi;

use crate::commands::{self, MenuCommand};

const TEXT_LIMIT: usize = 3500;
/// Long-poll is 50s; keep a small margin so a dead socket recovers instead of
/// sitting on frankenstein's default 500s global timeout.
const HTTP_TIMEOUT: Duration = Duration::from_secs(70);

#[derive(Clone, Debug)]
pub enum EditTarget {
    Inline(String),
    Chat { chat_id: i64, message_id: i32 },
}

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
            .allowed_updates(vec![
                AllowedUpdate::Message,
                AllowedUpdate::GuestMessage,
                AllowedUpdate::CallbackQuery,
            ])
            .build();
        self.bot
            .get_updates(&params)
            .map(|response| response.result)
            .map_err(|err| err.to_string())
    }

    pub fn answer_guest(
        &self,
        query_id: &str,
        text: &str,
        markup: Option<InlineKeyboardMarkup>,
    ) -> Result<EditTarget, String> {
        let article = InlineQueryResultArticle::builder()
            .id("1")
            .title("Secretary")
            .input_message_content(
                InputTextMessageContent::builder()
                    .message_text(clip(text))
                    .build(),
            )
            .maybe_reply_markup(markup)
            .build();
        let params = AnswerGuestQueryParams::builder()
            .guest_query_id(query_id)
            .result(InlineQueryResult::from(article))
            .build();
        self.bot
            .answer_guest_query(&params)
            .map(|response| EditTarget::Inline(response.result.inline_message_id))
            .map_err(|err| err.to_string())
    }

    pub fn send(
        &self,
        chat_id: i64,
        text: &str,
        markup: Option<InlineKeyboardMarkup>,
    ) -> Result<EditTarget, String> {
        let params = SendMessageParams::builder()
            .chat_id(chat_id)
            .text(clip(text))
            .maybe_reply_markup(markup.map(ReplyMarkup::InlineKeyboardMarkup))
            .build();
        self.bot
            .send_message(&params)
            .map(|response| EditTarget::Chat {
                chat_id,
                message_id: response.result.message_id,
            })
            .map_err(|err| err.to_string())
    }

    pub fn edit(
        &self,
        target: &EditTarget,
        text: &str,
        markup: Option<InlineKeyboardMarkup>,
    ) -> Result<(), String> {
        let params = match target {
            EditTarget::Inline(id) => EditMessageTextParams::builder()
                .text(clip(text))
                .maybe_reply_markup(markup.clone())
                .inline_message_id(id)
                .build(),
            EditTarget::Chat {
                chat_id,
                message_id,
            } => EditMessageTextParams::builder()
                .text(clip(text))
                .maybe_reply_markup(markup)
                .chat_id(*chat_id)
                .message_id(*message_id)
                .build(),
        };
        self.bot
            .edit_message_text(&params)
            .map(|_| ())
            .map_err(|err| err.to_string())
    }

    pub fn answer_callback(&self, callback_id: &str, text: Option<&str>) -> Result<(), String> {
        let params = AnswerCallbackQueryParams::builder()
            .callback_query_id(callback_id)
            .maybe_text(text.map(str::to_string))
            .build();
        self.bot
            .answer_callback_query(&params)
            .map(|_| ())
            .map_err(|err| err.to_string())
    }

    /// Converge Telegram's default-scope command menu to `desired`.
    /// Reads first and skips the write when already equal.
    pub fn sync_commands(&self, desired: &[MenuCommand]) -> Result<CommandSync, String> {
        let current = self.get_commands()?;
        let pairs: Vec<(String, String)> = current
            .iter()
            .map(|command| (command.command.clone(), command.description.clone()))
            .collect();
        if commands::commands_match(&pairs, desired) {
            return Ok(CommandSync::Unchanged);
        }
        if desired.is_empty() {
            self.delete_commands()?;
        } else {
            self.set_commands(desired)?;
        }
        Ok(CommandSync::Updated {
            from: current.len(),
            to: desired.len(),
        })
    }

    fn get_commands(&self) -> Result<Vec<BotCommand>, String> {
        let params = GetMyCommandsParams::builder().build();
        self.bot
            .get_my_commands(&params)
            .map(|response| response.result)
            .map_err(|err| err.to_string())
    }

    fn set_commands(&self, desired: &[MenuCommand]) -> Result<(), String> {
        let commands = desired
            .iter()
            .map(|command| {
                BotCommand::builder()
                    .command(command.command.to_string())
                    .description(command.description.to_string())
                    .build()
            })
            .collect();
        let params = SetMyCommandsParams::builder().commands(commands).build();
        self.bot
            .set_my_commands(&params)
            .map(|_| ())
            .map_err(|err| err.to_string())
    }

    fn delete_commands(&self) -> Result<(), String> {
        let params = DeleteMyCommandsParams::builder().build();
        self.bot
            .delete_my_commands(&params)
            .map(|_| ())
            .map_err(|err| err.to_string())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CommandSync {
    Unchanged,
    Updated { from: usize, to: usize },
}

pub fn buttons(action_id: &str) -> InlineKeyboardMarkup {
    let confirm = InlineKeyboardButton::builder()
        .text("Confirm")
        .callback_data(format!("c:{action_id}"))
        .build();
    let cancel = InlineKeyboardButton::builder()
        .text("Cancel")
        .callback_data(format!("x:{action_id}"))
        .build();
    InlineKeyboardMarkup::builder()
        .inline_keyboard(vec![vec![confirm, cancel]])
        .build()
}

pub fn empty_keyboard() -> InlineKeyboardMarkup {
    InlineKeyboardMarkup::builder()
        .inline_keyboard(Vec::new())
        .build()
}

fn clip(text: &str) -> String {
    let mut clipped: String = text.chars().take(TEXT_LIMIT).collect();
    if text.chars().count() > TEXT_LIMIT {
        clipped.push('…');
    }
    clipped
}
