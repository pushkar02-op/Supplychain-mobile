import logging

from app.db.models.user import User
from app.db.session import SessionLocal

try:
    db = SessionLocal()
    user = db.query(User).filter(User.username == "uom_tester").first()
    if user:
        user.is_admin = True
        db.commit()
        print("SUCCESS: Promoted uom_tester to admin")
    else:
        print("ERROR: User uom_tester not found")
    db.close()
except Exception as e:
    print(f"EXCEPTION: {e}")
