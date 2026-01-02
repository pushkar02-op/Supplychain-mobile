import logging
import os
import sys

# Ensure we can find the app module
# If running as `python app/create_admin.py` from /app, parent is /app.
sys.path.append(os.getcwd())

from app.core.security import hash_password
from app.db.models.user import User
from app.db.session import SessionLocal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def create_admin():
    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.username == "admin").first()
        if not admin:
            logger.info("Creating admin user...")
            admin = User(
                username="admin",
                full_name="System Admin",
                hashed_password=hash_password("admin"),
                is_admin=True,
                is_active=True,
            )
            db.add(admin)
            db.commit()
            logger.info("Admin created.")
        else:
            logger.info("Admin exists.")
            if not admin.is_admin:
                admin.is_admin = True
                db.commit()
                logger.info("Promoted to admin.")
    except Exception as e:
        logger.error(f"Error creating admin: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    create_admin()
