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
