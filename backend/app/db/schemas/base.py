from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class SchemaModel(BaseModel):
    model_config = ConfigDict(json_encoders={Decimal: lambda v: float(v)})
