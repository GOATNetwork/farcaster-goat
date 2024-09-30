#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::Config;

    #[test]
    fn test_process_button_buy_boost() {
        // Mock configuration with a test domain
        let config = Config {
            domain: "http://localhost".to_string(),
        };
        
        // Test the Buy & Boost button
        let result = process_button(1, &config).unwrap();
        
        // Assert the correct image and buttons are returned
        assert_eq!(result.0, "http://localhost/assets/buy_boost.png");
        assert_eq!(result.1[0].label, "Confirm");
        assert_eq!(result.1[1].label, "Back");
    }

    #[test]
    fn test_process_button_add_liquidity() {
        // Mock configuration with a test domain
        let config = Config {
            domain: "http://localhost".to_string(),
        };

        // Test the Add Liquidity button
        let result = process_button(2, &config).unwrap();

        // Assert the correct image and buttons are returned
        assert_eq!(result.0, "http://localhost/assets/add_liquidity.png");
        assert_eq!(result.1[0].label, "Add");
        assert_eq!(result.1[1].label, "Back");
    }

    #[test]
    fn test_process_button_invalid() {
        // Mock configuration with a test domain
        let config = Config {
            domain: "http://localhost".to_string(),
        };

        // Test an invalid button index
        let result = process_button(999, &config);

        // Assert that the function returns an error
        assert!(result.is_err());
    }
}
