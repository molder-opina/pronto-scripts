-- Normalize legacy order workflow values to canonical statuses.
-- Date: 2026-03-15

UPDATE pronto_orders
SET workflow_status = CASE workflow_status
    WHEN 'requested' THEN 'new'
    WHEN 'waiter_accepted' THEN 'queued'
    WHEN 'kitchen_in_progress' THEN 'preparing'
    WHEN 'ready_for_delivery' THEN 'ready'
    WHEN 'served' THEN 'delivered'
    WHEN 'awaiting_payment' THEN 'delivered'
    WHEN 'completed' THEN 'paid'
    ELSE workflow_status
END
WHERE workflow_status IN (
    'requested',
    'waiter_accepted',
    'kitchen_in_progress',
    'ready_for_delivery',
    'served',
    'awaiting_payment',
    'completed'
);

UPDATE pronto_order_status_history
SET status = CASE status
    WHEN 'requested' THEN 'new'
    WHEN 'waiter_accepted' THEN 'queued'
    WHEN 'kitchen_in_progress' THEN 'preparing'
    WHEN 'ready_for_delivery' THEN 'ready'
    WHEN 'served' THEN 'delivered'
    WHEN 'awaiting_payment' THEN 'delivered'
    WHEN 'completed' THEN 'paid'
    ELSE status
END
WHERE status IN (
    'requested',
    'waiter_accepted',
    'kitchen_in_progress',
    'ready_for_delivery',
    'served',
    'awaiting_payment',
    'completed'
);
