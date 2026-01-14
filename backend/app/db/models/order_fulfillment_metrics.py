from app.db.models.base_class import Base
from sqlalchemy import Column, Float, Integer


class OrderFulfillmentMetrics(Base):
    __tablename__ = "order_fulfillment_metrics"

    order_id = Column(Integer, primary_key=True)
    item_id = Column(Integer, nullable=False)
    mart_id = Column(Integer, nullable=False)
    fulfillment_time_minutes = Column(Float, nullable=False)

    def __repr__(self):
        return f"<OrderMetrics(order={self.order_id}, time={self.fulfillment_time_minutes})>"
