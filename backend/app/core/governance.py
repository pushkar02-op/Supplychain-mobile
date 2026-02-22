from decimal import Decimal

from app.core.config import settings
from pydantic import BaseModel, Field, model_validator


class DriftThresholds(BaseModel):
    critical_ratio: Decimal = Field(default=Decimal("0.05"), gt=Decimal("0"))


class ForecastThresholds(BaseModel):
    critical_days: int = Field(default=3, gt=0)
    reorder_soon_days: int = Field(default=7, gt=0)
    watch_days: int = Field(default=14, gt=0)

    @model_validator(mode="after")
    def validate_ordering(self):
        if not (self.critical_days < self.reorder_soon_days < self.watch_days):
            raise ValueError(
                "forecast thresholds must satisfy "
                "critical_days < reorder_soon_days < watch_days"
            )
        return self


class InventorySignalThresholds(BaseModel):
    fast_depletion_ratio: Decimal = Field(default=Decimal("1.5"), gt=Decimal("0"))
    low_stock_ratio: Decimal = Field(default=Decimal("0.2"), gt=Decimal("0"))
    absolute_low_stock: Decimal = Field(default=Decimal("10.0"), gt=Decimal("0"))


class GovernanceThresholds(BaseModel):
    drift: DriftThresholds = Field(default_factory=DriftThresholds)
    forecast: ForecastThresholds = Field(default_factory=ForecastThresholds)
    inventory: InventorySignalThresholds = Field(
        default_factory=InventorySignalThresholds
    )


def load_governance_thresholds() -> GovernanceThresholds:
    return GovernanceThresholds(
        drift=DriftThresholds(
            critical_ratio=Decimal(str(settings.DRIFT_CRITICAL_RATIO))
        ),
        forecast=ForecastThresholds(
            critical_days=settings.FORECAST_CRITICAL_DAYS,
            reorder_soon_days=settings.FORECAST_REORDER_SOON_DAYS,
            watch_days=settings.FORECAST_WATCH_DAYS,
        ),
        inventory=InventorySignalThresholds(),
    )


thresholds = load_governance_thresholds()
