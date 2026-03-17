from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    JWT_SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    ENVIRONMENT: str = "development"
    SEED_INITIAL_DATA: bool = True
    POSTGRES_USER: str = ""
    POSTGRES_PASSWORD: str = ""
    POSTGRES_DB: str = ""
    POSTGRES_PORT: str = ""
    POSTGRES_HOST: str = ""
    INVOICE_UPLOAD_DIR: str = "invoices"
    STORAGE_ROOT: str = "invoices"
    FILE_UPLOAD_MAX_MB: int = 10
    CORS_ORIGINS: str = "*"
    DRIFT_CRITICAL_RATIO: str = "0.05"
    FORECAST_CRITICAL_DAYS: int = 3
    FORECAST_REORDER_SOON_DAYS: int = 7
    FORECAST_WATCH_DAYS: int = 14

    class Config:
        env_file = ".env"


settings = Settings()
