# Import all the models, so that Base has them before being
# imported by Alembic
from app.db.models import *  # noqa
from app.db.models.base_class import Base  # noqa
