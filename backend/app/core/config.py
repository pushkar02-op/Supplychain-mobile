import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL")
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY")
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    POSTGRES_USER = os.getenv("POSTGRES_USER")
    POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")
    POSTGRES_DB = os.getenv("POSTGRES_DB")
    POSTGRES_PORT = os.getenv("POSTGRES_PORT")
    POSTGRES_HOST = os.getenv("POSTGRES_HOST")
    INVOICE_UPLOAD_DIR: str = "invoices"
    STORAGE_ROOT: str = os.getenv("STORAGE_ROOT", "invoices")
    SEED_INITIAL_DATA: bool = True
    DRIFT_CRITICAL_RATIO: str = os.getenv("DRIFT_CRITICAL_RATIO", "0.05")
    FORECAST_CRITICAL_DAYS: int = int(os.getenv("FORECAST_CRITICAL_DAYS", "3"))
    FORECAST_REORDER_SOON_DAYS: int = int(os.getenv("FORECAST_REORDER_SOON_DAYS", "7"))
    FORECAST_WATCH_DAYS: int = int(os.getenv("FORECAST_WATCH_DAYS", "14"))

    class Config:
        env_file = ".env"


settings = Settings()
