use serde::Serialize;
use crate::errors::AppError;

#[derive(Serialize)]
pub struct Button {
    pub label: String,
}

use crate::config::Config;

pub fn process_button(button_index: usize, config: &Config) -> Result<(String, Vec<Button>), AppError> {
    match button_index {
        1 => Ok((
            format!("{}/assets/buy_boost.png", config.domain),
            vec![
                Button { label: "Confirm".to_string() },
                Button { label: "Back".to_string() },
            ],
        )),
        2 => Ok((
            format!("{}/assets/add_liquidity.png", config.domain),
            vec![
                Button { label: "Add".to_string() },
                Button { label: "Back".to_string() },
            ],
        )),
        3 => Ok((
            format!("{}/assets/gift.png", config.domain),
            vec![
                Button { label: "Send Gift".to_string() },
                Button { label: "Back".to_string() },
            ],
        )),
        4 => Ok((
            format!("{}/assets/more.png", config.domain),
            vec![
                Button { label: "Reward".to_string() },
                Button { label: "Bid".to_string() },
                Button { label: "Top-up".to_string() },
                Button { label: "Back".to_string() },
            ],
        )),
        _ => {
            // Log an error if the button index is invalid
            Err(AppError::BadRequest(format!("Invalid button index: {}", button_index)))
        }
    }
}
