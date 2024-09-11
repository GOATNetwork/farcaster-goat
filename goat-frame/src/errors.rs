use thiserror::Error;
use actix_web::{HttpResponse, ResponseError};
use log::warn;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Internal server error")]
    InternalServerError,
   
    #[error("Bad request: {0}")]
    BadRequest(String),
}

impl ResponseError for AppError {
    fn error_response(&self) -> HttpResponse {
        match *self {
            AppError::InternalServerError => {
                // Log an internal server error warning but continue running
                warn!("Internal server error occurred.");
                HttpResponse::InternalServerError().json("Internal server error")
            }
            AppError::BadRequest(ref message) => {
                // Log a bad request error
                warn!("Bad request: {}", message);
                HttpResponse::BadRequest().json(message)
            }
        }
    }
}
