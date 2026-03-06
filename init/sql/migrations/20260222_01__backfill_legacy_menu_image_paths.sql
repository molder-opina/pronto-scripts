-- Backfill image_path for legacy menu items (idempotent).
-- Applies only when image_path is null/empty.

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/camarones_ajillo.png'
WHERE name = 'Crispy Calamari'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/pan_frances.png'
WHERE name = 'Bruschetta'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/ensalada_cesar.png'
WHERE name = 'Caesar Salad'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/hamburguesa_pollo.png'
WHERE name = 'Grilled Chicken Burger'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/arrachera.png'
WHERE name = 'Beef Steak'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/tacos_pescado.png'
WHERE name = 'Fish Tacos'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/pastel_chocolate.png'
WHERE name = 'Chocolate Lava Cake'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/cheesecake_rojo.png'
WHERE name = 'Cheesecake'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/helado.png'
WHERE name = 'Ice Cream'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/cafe_americano.png'
WHERE name = 'Coffee'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/jugo_naranja.png'
WHERE name = 'Fresh Juice'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/coca_cola.png'
WHERE name = 'Soft Drink'
  AND (image_path IS NULL OR btrim(image_path) = '');

UPDATE pronto_menu_items
SET image_path = '/assets/pronto/menu/especialidades_pasta_carbonara.png'
WHERE name = 'Pasta Carbonara'
  AND (image_path IS NULL OR btrim(image_path) = '');
