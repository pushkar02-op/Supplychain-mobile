from fastapi import FastAPI
from app.api import router as api_router
import os
import subprocess

app = FastAPI(title="Fruit Vendor Tool")

app.include_router(api_router)


@app.on_event("startup")
def startup():
    pass

def run_migrations():
    os.system("alembic upgrade head")

if __name__ == "__main__":
    run_migrations()