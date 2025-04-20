from fastapi import FastAPI
from app.api import router as api_router
import os
import subprocess

app = FastAPI(title="Fruit Vendor Tool")

app.include_router(api_router)

# Run Alembic migrations automatically in development
if os.getenv("ENV", "dev") == "dev":
    try:
        print("🔄 Autogenerating migration...")
        subprocess.run([
            "alembic", "revision", "--autogenerate", "-m", "Auto migration"
        ], check=True)
    except subprocess.CalledProcessError:
        print("⚠️  No changes detected or revision already exists.")

    print("⬆️  Applying migrations...")
    subprocess.run(["alembic", "upgrade", "head"], check=True)
