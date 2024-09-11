use actix_web::{web, App, HttpServer, HttpResponse};
use actix_files as fs;
use serde::{Deserialize, Serialize};
use log::{info, error}; // Import error to log warnings
use dotenv::dotenv;

mod frame_logic;
mod errors;
mod config;

use crate::errors::AppError;
use crate::config::Config;
use crate::frame_logic::Button;

#[derive(Deserialize)]
struct FrameRequest {
    untrusted_data: UntrustedData, // Use snake case
}

#[derive(Deserialize)]
struct UntrustedData {
    button_index: usize, // Use snake case
}

#[derive(Serialize)]
struct FrameResponse {
    image: String,
    buttons: Vec<Button>,
}

async fn index(config: web::Data<Config>) -> Result<HttpResponse, AppError> {
    let html = format!(r#"
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Moxie Store Frame</title>
        <meta property="fc:frame" content="vNext" />
        <meta property="fc:frame:image" content="{}/assets/main.png" />
        <meta property="fc:frame:button:1" content="Buy & Boost" />
        <meta property="fc:frame:button:2" content="Add Liquidity" />
        <meta property="fc:frame:button:3" content="Gift" />
        <meta property="fc:frame:button:4" content="More" />
        <meta property="fc:frame:post_url" content="{}/api/frame" />
    </head>
    <body>
        <h1>Moxie Store Frame</h1>
    </body>
    </html>
    "#, config.domain, config.domain);

    // Check if the html is properly formed; log an error and continue if it's not
    if html.is_empty() {
        error!("Failed to generate HTML. Falling back to default content.");
        return Err(AppError::InternalServerError); // Logs the error, does not halt the program
    } // may need to design this with proper typescript elements from deno to layer on to this through the binary that it can present through. 

    Ok(HttpResponse::Ok().content_type("text/html").body(html))
}

async fn handle_frame(req: web::Json<FrameRequest>, config: web::Data<Config>) -> Result<HttpResponse, AppError> {
    info!("Received button click: {}", req.untrusted_data.button_index);

    // Handle frame logic and return an error if an asset fails to load
    match frame_logic::process_button(req.untrusted_data.button_index, &config) {
        Ok((image, buttons)) => {
            let response = FrameResponse { image, buttons };
            Ok(HttpResponse::Ok().json(response))
        }
        Err(err) => {
            error!("Failed to process button click: {}. Error: {}", req.untrusted_data.button_index, err);
            // Return default frame with an error logged
            let response = FrameResponse {
                image: format!("{}/assets/main.png", config.domain),
                buttons: vec![
                    Button { label: "Error Occurred".to_string() },
                    Button { label: "Try Again".to_string() },
                ],
            };
            Ok(HttpResponse::Ok().json(response)) // Return the response despite the error
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();
    env_logger::init();

    let config = Config::from_env().expect("Server configuration");
    let config = web::Data::new(config);

    HttpServer::new(move || {
        App::new()
            .app_data(config.clone())
            .wrap(actix_web::middleware::Logger::default())
            .service(fs::Files::new("/assets", "assets").show_files_listing())
            .route("/", web::get().to(index))
            .route("/api/frame", web::post().to(handle_frame))
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}

// next add the line 317 DEPLOYMENT.md