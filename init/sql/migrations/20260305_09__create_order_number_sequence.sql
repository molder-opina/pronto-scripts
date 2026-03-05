-- Migration: Create the sequence for order numbers
-- Date: 2026-03-05

BEGIN;

CREATE SEQUENCE IF NOT EXISTS pronto_orders_order_number_seq
    START WITH 1000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

COMMIT;
