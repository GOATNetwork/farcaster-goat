#[cfg(test)]
mod integration_tests {
    use actix_web::{test, web, App};
    use crate::{handle_frame, index, Config};

    #[actix_web::test]
    async fn test_index_page() {
        // Create a mock application with the same routes as in main.rs
        let config = web::Data::new(Config {
            domain: "http://localhost".to_string(),
        });

        let app = test::init_service(
            App::new()
                .app_data(config.clone())
                .route("/", web::get().to(index))
        ).await;

        // Simulate a GET request to the index page
        let req = test::TestRequest::get().uri("/").to_request();
        let resp = test::call_service(&app, req).await;

        // Assert that the response has a 200 OK status
        assert!(resp.status().is_success());
    }

    #[actix_web::test]
    async fn test_handle_frame_valid_button() {
        // Create a mock application with the same routes as in main.rs
        let config = web::Data::new(Config {
            domain: "http://localhost".to_string(),
        });

        let app = test::init_service(
            App::new()
                .app_data(config.clone())
                .route("/api/frame", web::post().to(handle_frame))
        ).await;

        // Create a valid request with a button index of 1 (Buy & Boost)
        let req = test::TestRequest::post()
            .uri("/api/frame")
            .set_json(&serde_json::json!({
                "untrusted_data": {
                    "button_index": 1
                }
            }))
            .to_request();

        // Simulate the POST request
        let resp = test::call_service(&app, req).await;

        // Assert that the response has a 200 OK status
        assert!(resp.status().is_success());
    }

    #[actix_web::test]
    async fn test_handle_frame_invalid_button() {
        // Create a mock application with the same routes as in main.rs
        let config = web::Data::new(Config {
            domain: "http://localhost".to_string(),
        });

        let app = test::init_service(
            App::new()
                .app_data(config.clone())
                .route("/api/frame", web::post().to(handle_frame))
        ).await;

        // Create an invalid request with an out-of-range button index (e.g., 999)
        let req = test::TestRequest::post()
            .uri("/api/frame")
            .set_json(&serde_json::json!({
                "untrusted_data": {
                    "button_index": 999
                }
            }))
            .to_request();

        // Simulate the POST request
        let resp = test::call_service(&app, req).await;

        // Assert that the response has a 200 OK status
        assert!(resp.status().is_success());
    }
}
