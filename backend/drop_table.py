from sqlalchemy import create_engine, text
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://user:password@db:5432/supply_chain"
)
engine = create_engine(DATABASE_URL)

with engine.connect() as conn:
    print("Dropping domain_events table...")
    conn.execute(text("DROP TABLE IF EXISTS domain_events CASCADE"))
    conn.commit()
    print("Dropped.")
