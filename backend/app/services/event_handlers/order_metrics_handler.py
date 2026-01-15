from app.db.models.order import Order
from app.db.models.order_fulfillment_metrics import OrderFulfillmentMetrics
from app.db.schemas.domain_event import DomainEventBase
from sqlalchemy.orm import Session


def handle_order_metrics(session: Session, event: DomainEventBase):
    """
    Insert OrderFulfillmentMetrics projection.
    Calculates time from Order Creation to Fulfillment (Event occurred_at).
    """
    payload = event.payload
    order_id = payload.get("order_id")
    item_id = payload.get("item_id")
    mart_id = payload.get("mart_id")

    # Fetch Order to get created_at
    # Allowed read for projection
    order = session.get(Order, order_id)
    if not order:
        return  # Cannot calculate metrics

    completion_time = event.occurred_at
    creation_time = order.created_at

    duration = completion_time - creation_time
    minutes = duration.total_seconds() / 60.0

    metric = OrderFulfillmentMetrics(
        order_id=order_id,
        item_id=item_id,
        mart_id=mart_id,
        fulfillment_time_minutes=minutes,
    )
    session.add(metric)
