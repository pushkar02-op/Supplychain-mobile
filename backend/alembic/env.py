import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()

from logging.config import fileConfig

from sqlalchemy import pool

from alembic import context

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Overriding sqlalchemy.url with .env variable
DATABASE_URL = os.getenv("DATABASE_URL")
print(DATABASE_URL)
if DATABASE_URL:
    config.set_main_option("sqlalchemy.url", DATABASE_URL)

# add your model's MetaData object here
# for 'autogenerate' support
# from myapp import mymodel
# target_metadata = mymodel.Base.metadata
from app.db.base import Base

target_metadata = Base.metadata

# other values from the config, defined by the needs of env.py,
# can be acquired:
# my_important_option = config.get_main_option("my_important_option")
# ... etc.


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.

    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


# ✅ Helper: Run all SQL files from views directory
def apply_custom_sql_views(connection):
    views_dir = os.path.join(os.path.dirname(__file__), "../app/db/views")
    if not os.path.isdir(views_dir):
        print("⚠️ Views directory does not exist, skipping.")
        return

    for file in sorted(os.listdir(views_dir)):
        if file.endswith(".sql"):
            file_path = os.path.join(views_dir, file)
            print(f"🔹 Applying view: {file}")
            with open(file_path, "r", encoding="utf-8") as f:
                sql = f.read()
                connection.execute(text(sql))


def run_migrations_online() -> None:
    """Run migrations in 'online' mode.
    In this scenario we need to create an Engine
    and associate a connection with the context.

    """

    connectable = create_engine(DATABASE_URL, poolclass=pool.NullPool)

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )

        with context.begin_transaction():
            context.run_migrations()

            # Check if all required tables exist
            REQUIRED_TABLES = ["item", "inventory_txn", "uom", "mart", "dispatch_entry"]

            placeholders = ", ".join([f":t{i}" for i in range(len(REQUIRED_TABLES))])

            query = text(
                f"""
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_name IN ({placeholders})
            """
            )

            params = {f"t{i}": table for i, table in enumerate(REQUIRED_TABLES)}

            result = connection.execute(query, params)
            count = result.scalar()

            if count == len(REQUIRED_TABLES):
                print("✅ All required tables detected, applying views.")
                apply_custom_sql_views(connection)
            else:
                print(
                    f"⚠️ Not all required tables exist ({count}/{len(REQUIRED_TABLES)}), skipping view application."
                )


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
