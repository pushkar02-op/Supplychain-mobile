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

    class Config:
        env_file = ".env"


settings = Settings()
