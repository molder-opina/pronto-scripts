-- Migration: add flag for quick-serve (no cocina) items
-- Date: 2025-11-08
-- Description: allow marcar productos que puede entregar el mesero sin pasar por cocina

ALTER TABLE menu_items
ADD COLUMN is_quick_serve TINYINT(1) NOT NULL DEFAULT 0
COMMENT '1 = lo entrega el mesero sin pasar por cocina';

CREATE INDEX idx_menu_items_quick_serve ON menu_items(is_quick_serve);

UPDATE menu_items mi
JOIN menu_categories mc ON mc.id = mi.category_id
SET mi.is_quick_serve = 1
WHERE mc.name = 'Bebidas';
