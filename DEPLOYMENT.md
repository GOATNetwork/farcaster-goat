# Farcaster Moxie GOAT Frame Application

## Table of Contents
1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Project Setup](#project-setup)
4. [Project Structure](#project-structure)
5. [Implementation](#implementation)
6. [Asset Preparation](#asset-preparation)
7. [Local Development and Testing](#local-development-and-testing)
8. [AWS Lightsail Deployment](#aws-lightsail-deployment)
9. [Monitoring and Logging](#monitoring-and-logging)
10. [Security Considerations](#security-considerations)
11. [Testing and Validation](#testing-and-validation)
12. [Maintenance and Updates](#maintenance-and-updates)
13. [Troubleshooting](#troubleshooting)
14. [Contributing](#contributing)
15. [License](#license)

## Introduction

This document provides a comprehensive guide for building, deploying, and maintaining a production-ready Farcaster Frame application using Rust. The application, named "Moxie Store Frame," showcases interactive elements within the Farcaster ecosystem, allowing users to navigate through different states using frame buttons.

## Prerequisites

Before starting, ensure you have the following:

- Rust (minimum version 1.54.0)
- An AWS account with Lightsail access
- A registered domain name
- Basic knowledge of Rust, web development, and Linux server administration

## Project Setup

1. Install Rust (if not already installed):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   rustc --version
   ```

2. Create the project:
   ```bash
   cargo new farcaster-moxie-frame
   cd farcaster-moxie-frame
   ```

3. Update `Cargo.toml` with the following content:
   ```toml
   [package]
   name = "farcaster-moxie-frame"
   version = "0.1.0"
   edition = "2021"

   [dependencies]
   actix-web = "4.3.1"
   actix-files = "0.6.2"
   serde = { version = "1.0.160", features = ["derive"] }
   serde_json = "1.0.96"
   env_logger = "0.10.0"
   log = "0.4.17"
   dotenv = "0.15.0"
   thiserror = "1.0.40"
   envy = "0.4.2"
   ```

## Project Structure

Organize your project with the following structure:

```
farcaster-moxie-frame/
├── src/
│   ├── main.rs
│   ├── frame_logic.rs
│   ├── errors.rs
│   └── config.rs
├── assets/
│   ├── main.png
│   ├── buy_boost.png
│   ├── add_liquidity.png
│   ├── gift.png
│   └── more.png
├── Cargo.toml
├── Cargo.lock
├── .env
└── README.md
```

## Implementation

### src/main.rs

This file contains the main application logic, including route definitions and server setup.

```rust
use actix_web::{web, App, HttpServer, HttpResponse, Responder};
use actix_files as fs;
use serde::{Deserialize, Serialize};
use log::{info, error};
use dotenv::dotenv;

mod frame_logic;
mod errors;
mod config;

use crate::errors::AppError;
use crate::config::Config;

#[derive(Deserialize)]
struct FrameRequest {
    untrustedData: UntrustedData,
}

#[derive(Deserialize)]
struct UntrustedData {
    buttonIndex: usize,
}

#[derive(Serialize)]
struct FrameResponse {
    image: String,
    buttons: Vec<Button>,
}

#[derive(Serialize)]
struct Button {
    label: String,
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
    Ok(HttpResponse::Ok().content_type("text/html").body(html))
}

async fn handle_frame(req: web::Json<FrameRequest>, config: web::Data<Config>) -> Result<HttpResponse, AppError> {
    info!("Received button click: {}", req.untrustedData.buttonIndex);
    let (image, buttons) = frame_logic::process_button(req.untrustedData.buttonIndex, &config)?;
    let response = FrameResponse { image, buttons };
    Ok(HttpResponse::Ok().json(response))
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
```

### src/frame_logic.rs

This file contains the logic for processing button clicks and returning appropriate responses.

```rust
use crate::errors::AppError;
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
        _ => Ok((
            format!("{}/assets/main.png", config.domain),
            vec![
                Button { label: "Buy & Boost".to_string() },
                Button { label: "Add Liquidity".to_string() },
                Button { label: "Gift".to_string() },
                Button { label: "More".to_string() },
            ],
        )),
    }
}

pub struct Button {
    pub label: String,
}
```

### src/errors.rs

This file defines custom error types for the application.

```rust
use thiserror::Error;
use actix_web::{HttpResponse, ResponseError};

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Internal server error")]
    InternalServerError,
    
    #[error("Bad request: {0}")]
    BadRequest(String),
}

impl ResponseError for AppError {
    fn error_response(&self) -> HttpResponse {
        match self {
            AppError::InternalServerError => HttpResponse::InternalServerError().json("Internal server error"),
            AppError::BadRequest(msg) => HttpResponse::BadRequest().json(msg),
        }
    }
}
```

### src/config.rs

This file handles configuration management using environment variables.

```rust
use serde::Deserialize;

#[derive(Clone, Deserialize)]
pub struct Config {
    pub domain: String,
}

impl Config {
    pub fn from_env() -> Result<Self, envy::Error> {
        envy::from_env::<Config>()
    }
}
```

### .env file

Create a `.env` file in the project root with the following content:

```
DOMAIN=https://your-domain.com
```

Replace `your-domain.com` with your actual domain.

## Asset Preparation

1. Create high-quality PNG images (1200x630px) for each state:
   - main.png
   - buy_boost.png
   - add_liquidity.png
   - gift.png
   - more.png

2. Optimize these images for web use. You can use tools like ImageOptim or TinyPNG.

3. Place the optimized images in the `assets` folder of your project.

## Local Development and Testing

1. Run the application locally:
   ```bash
   cargo run
   ```

2. Open http://localhost:8080 in a web browser to view the frame.

3. Test the `/api/frame` endpoint using cURL or Postman:
   ```bash
   curl -X POST http://localhost:8080/api/frame \
        -H "Content-Type: application/json" \
        -d '{"untrustedData": {"buttonIndex": 1}}'
   ```

4. Implement unit and integration tests:
   - Create a `tests` directory in your `src` folder.
   - Write unit tests for `frame_logic.rs` functions.
   - Write integration tests for HTTP endpoints.

## AWS Lightsail Deployment

1. Create a Lightsail instance:
   - Go to AWS Lightsail console
   - Click "Create instance"
   - Choose "OS Only" and select Ubuntu 20.04 LTS
   - Select an instance plan (recommend at least 2 GB RAM, 1 vCPU)
   - Name your instance and create it

2. Configure your instance:
   - Attach a static IP
   - Open ports: HTTP (80), HTTPS (443), and Custom TCP (8080)

3. Connect to your instance via SSH

4. Update the system and install dependencies:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y build-essential pkg-config libssl-dev
   ```

5. Install Rust:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

6. Clone your repository or upload project files

7. Build the project:
   ```bash
   cd farcaster-moxie-frame
   cargo build --release
   ```

8. Set up Nginx as reverse proxy:
   ```bash
   sudo apt install nginx
   ```

   Configure Nginx (/etc/nginx/sites-available/default):
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;

       location / {
           proxy_pass http://127.0.0.1:8080;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

9. Set up SSL with Certbot:
   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```

10. Set up environment variables:
    ```bash
    echo "DOMAIN=https://your-domain.com" > .env
    ```

11. Create a systemd service:

    /etc/systemd/system/farcaster-frame.service:
    ```
    [Unit]
    Description=Farcaster Frame Rust Application
    After=network.target

    [Service]
    User=ubuntu
    WorkingDirectory=/home/ubuntu/farcaster-moxie-frame
    ExecStart=/home/ubuntu/farcaster-moxie-frame/target/release/farcaster-moxie-frame
    Restart=always
    Environment="RUST_LOG=info"

    [Install]
    WantedBy=multi-user.target
    ```

    Enable and start the service:
    ```bash
    sudo systemctl enable farcaster-frame
    sudo systemctl start farcaster-frame
    ```

## Monitoring and Logging

1. Set up log rotation:
   ```bash
   sudo nano /etc/logrotate.d/farcaster-frame
   ```

   Add the following content:
   ```
   /var/log/farcaster-frame.log {
       daily
       rotate 7
       compress
       delaycompress
       missingok
       notifempty
       create 644 ubuntu ubuntu
   }
   ```

2. Update the systemd service to output logs:
   ```bash
   sudo systemctl edit farcaster-frame
   ```

   Add the following:
   ```
   [Service]
   StandardOutput=append:/var/log/farcaster-frame.log
   StandardError=append:/var/log/farcaster-frame.log
   ```

   Restart the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart farcaster-frame
   ```

3. Consider setting up application performance monitoring (APM) tools like DataDog or New Relic for more comprehensive monitoring.

## Security Considerations

1. Set up a firewall:
   ```bash
   sudo ufw allow 22
   sudo ufw allow 80
   sudo ufw allow 443
   sudo ufw enable
   ```

2. Regularly update your system:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. Implement rate limiting in Nginx to prevent abuse:
   ```nginx
   http {
       limit_req_zone $binary_remote_addr zone=one:10m rate=1r/s;
       
       server {
           location /api/frame {
               limit_req zone=one burst=5;
               ...
           }
       }
   }
   ```

4. Use environment variables for sensitive information and never commit them to version control.

5. Keep your Rust dependencies up to date and regularly audit them for security vulnerabilities.

## Testing and Validation

1. Use the Farcaster Frame validator: https://warpcast.com/~/developers/frames

2. Test all possible user interactions:
   - Verify each button click produces the expected response
   - Ensure images are loading correctly
   - Check that all states are reachable

3. Verify SSL configuration: 
   - Use https://www.ssllabs.com/ssltest/ to check your SSL setup

4. Load test your application:
   - Use tools like Apache JMeter or k6 to simulate high traffic
   - Ensure your application can handle expected load without significant performance degradation

5. Perform security testing:
   - Use tools like OWASP ZAP to scan for common vulnerabilities
   - Conduct regular penetration testing

## Maintenance and Updates

1. Set up automated backups of your Lightsail instance:
   - Use AWS Lightsail snapshots feature
   - Configure daily automated snapshots

2. Implement a CI/CD pipeline:
   - Use GitHub Actions or GitLab CI to automate testing and deployment
   - Example GitHub Actions workflow:

   ```yaml
   name: CI/CD

   on:
     push:
       branches: [ main ]

   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
       - uses: actions/checkout@v2
       - name: Build
         run: cargo build --verbose
       - name: Run tests
         run: cargo test --verbose

     deploy:
       needs: test
       runs-on: ubuntu-latest
       steps:
       - name: Deploy to Lightsail
         env:
           PRIVATE_KEY: ${{ secrets.LIGHTSAIL_SSH_KEY }}
         run: |
           echo "$PRIVATE_KEY" > private_key && chmod 600 private_key
           ssh -o StrictHostKeyChecking=no -i private_key ubuntu@your-lightsail-ip '
             cd /path/to/your/project &&
             git pull origin main &&
             cargo build --release &&
             sudo systemctl restart farcaster-frame
           '
   ```

3. Regularly review and update dependencies:
   ```bash
   cargo update
   ```

4. Monitor application logs and performance metrics:
   - Regularly review `/var/log/farcaster-frame.log`
   - Set up alerts for error spikes or unusual activity

## Troubleshooting

1. If the frame doesn't load:
   - Check your domain's DNS settings
   - Verify Nginx configuration
   - Ensure SSL certificate is valid and properly configured

2. If button clicks don't work:
   - Check the Nginx logs for any 502 Bad Gateway errors
   - Verify that the Rust application is running (`systemctl status farcaster-frame`)
   - Check the application logs for any error messages

3. For performance issues:
   - Monitor CPU and memory usage on your Lightsail instance
   - Consider upgrading your Lightsail plan if resources are consistently maxed out
   - Optimize your Rust code and database queries if applicable

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Performance Optimization

1. Database Caching:
   If your application uses a database, implement caching to reduce database load:
   - Use Redis for in-memory caching
   - Implement query result caching in your Rust code

   Example of adding Redis caching:
   ```rust
   use redis::{Client, Commands};

   fn get_cached_data(key: &str) -> Result<String, redis::RedisError> {
       let client = Client::open("redis://127.0.0.1/")?;
       let mut con = client.get_connection()?;
       let cached: Option<String> = con.get(key)?;
       Ok(cached.unwrap_or_else(|| {
           let fresh_data = fetch_fresh_data();
           let _: () = con.set_ex(key, &fresh_data, 3600).unwrap();
           fresh_data
       }))
   }
   ```

2. Image Optimization:
   - Use WebP format for images to reduce file size while maintaining quality
   - Implement lazy loading for images not immediately visible
   - Use a Content Delivery Network (CDN) for serving static assets

3. Code Optimization:
   - Use the Rust compiler's optimization flags:
     ```bash
     RUSTFLAGS="-C target-cpu=native" cargo build --release
     ```
   - Profile your code using tools like `perf` or `flamegraph` to identify bottlenecks

## Scalability

1. Horizontal Scaling:
   - Design your application to be stateless, allowing for easy horizontal scaling
   - Use a load balancer to distribute traffic across multiple instances

2. Database Scaling:
   - If using a database, consider implementing read replicas
   - Use database connection pooling to manage connections efficiently

3. Microservices Architecture:
   - Consider breaking down your application into microservices for better scalability
   - Use Docker and Kubernetes for container orchestration

## Monitoring and Analytics

1. Prometheus and Grafana:
   - Set up Prometheus for metrics collection
   - Use Grafana for visualizing metrics and creating dashboards

   Example of adding Prometheus metrics to your Rust application:
   ```rust
   use prometheus::{Registry, Counter, Gauge};

   lazy_static! {
       static ref REGISTRY: Registry = Registry::new();
       static ref HTTP_REQUESTS_TOTAL: Counter = Counter::new("http_requests_total", "Total number of HTTP requests").expect("metric can be created");
       static ref HTTP_RESPONSE_TIME_SECONDS: Gauge = Gauge::new("http_response_time_seconds", "HTTP response time in seconds").expect("metric can be created");
   }

   fn init_metrics() {
       REGISTRY.register(Box::new(HTTP_REQUESTS_TOTAL.clone())).expect("collector can be registered");
       REGISTRY.register(Box::new(HTTP_RESPONSE_TIME_SECONDS.clone())).expect("collector can be registered");
   }
   ```

2. Error Tracking:
   - Implement error tracking using services like Sentry
   - Set up alerts for critical errors

3. User Analytics:
   - Implement user behavior tracking (ensure compliance with privacy laws)
   - Use tools like Mixpanel or Amplitude for user analytics

## Disaster Recovery

1. Backup Strategy:
   - Implement daily backups of your database and file system
   - Store backups in a separate geographical location

2. Recovery Plan:
   - Document step-by-step recovery procedures
   - Regularly test your recovery process to ensure it works

3. Multi-Region Deployment:
   - Consider deploying your application across multiple AWS regions for high availability

## Compliance and Legal

1. GDPR Compliance:
   - Implement user data protection measures
   - Provide options for users to request their data and the right to be forgotten

2. Terms of Service and Privacy Policy:
   - Draft and prominently display your Terms of Service and Privacy Policy
   - Ensure they comply with relevant laws and regulations

3. Cookie Consent:
   - Implement a cookie consent mechanism if your application uses cookies

## Documentation

1. API Documentation:
   - Use tools like Swagger or Redoc to generate API documentation
   - Keep API documentation up-to-date with each release

2. User Guide:
   - Create a comprehensive user guide explaining how to use your Farcaster Frame
   - Include examples and best practices

3. Developer Documentation:
   - Maintain detailed documentation for developers, including setup instructions and contribution guidelines

## Continuous Improvement

1. Feature Flagging:
   - Implement feature flags to easily enable/disable features in production
   - Use tools like LaunchDarkly or implement a custom solution

2. A/B Testing:
   - Set up A/B testing for new features to gather user feedback
   - Use tools like Optimizely or implement a custom solution

3. User Feedback Loop:
   - Implement mechanisms to collect user feedback
   - Regularly review and prioritize user feedback for future development

## Internationalization and Localization

1. i18n Support:
   - Implement internationalization support in your Rust application
   - Use libraries like `fluent-rs` for handling translations

2. Localization Process:
   - Set up a process for translating your application into multiple languages
   - Consider using translation management tools like Crowdin or Lokalise

## Security Enhancements

1. Web Application Firewall (WAF):
   - Set up AWS WAF to protect against common web exploits

2. DDoS Protection:
   - Implement AWS Shield for DDoS protection

3. Regular Security Audits:
   - Conduct regular security audits of your application and infrastructure
   - Consider hiring external security consultants for penetration testing

## Community Building

1. Open Source Contributions:
   - If your project is open source, provide clear contribution guidelines
   - Set up issue templates and pull request templates on GitHub

2. User Community:
   - Create a forum or Discord server for users to discuss your Farcaster Frame
   - Regularly engage with the community and address concerns

3. Showcase User Projects:
   - Create a gallery or showcase of projects built with your Farcaster Frame
   - Highlight innovative uses of your frame to inspire others

## Future Roadmap

1. Upcoming Features:
   - Maintain a public roadmap of upcoming features
   - Prioritize features based on user feedback and strategic goals

2. Deprecation Policy:
   - Clearly communicate any plans to deprecate features or APIs
   - Provide migration guides for users when deprecating significant functionality

3. Version Support:
   - Define and communicate your version support policy
   - Plan for long-term support of critical versions

## Conclusion

Building and maintaining a production-ready Farcaster Frame application is an ongoing process that requires attention to various aspects beyond just coding. By following this comprehensive guide, you'll be well-equipped to create a robust, scalable, and user-friendly application that can grow with your needs and provide value to your users.

Remember to regularly revisit and update each section of this guide as your project evolves and as new best practices emerge in the rapidly changing landscape of web development and blockchain technologies.