use frankenstein::client_ureq::Bot;
use frankenstein::inline_mode::{
    InlineQueryResult, InlineQueryResultArticle, InputTextMessageContent,
};
use frankenstein::methods::{
    AnswerCallbackQueryParams, AnswerGuestQueryParams, EditMessageTextParams, GetUpdatesParams,
    SendMessageParams,
};
use frankenstein::types::{AllowedUpdate, InlineKeyboardButton, InlineKeyboardMarkup, ReplyMarkup};
use frankenstein::updates::Update;
use frankenstein::TelegramApi;

const TEXT_LIMIT: usize = 3500;

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
        Self {
            bot: Bot::new(token),
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
