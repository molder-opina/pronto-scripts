-- ============================================================================
-- PRONTO SEED: Categories
-- ============================================================================
-- Creates menu categories with UPSERT logic
-- Run order: 0310 (after bootstrap, before menu items)
-- ============================================================================

-- Insert or update categories
INSERT INTO pronto_menu_categories (id, name, description, display_order)
VALUES
    (gen_random_uuid(), 'Combos', 'Combos listos para disfrutar', 1),
    (gen_random_uuid(), 'Hamburguesas', 'Opciones clásicas y gourmet', 2),
    (gen_random_uuid(), 'Pizzas', 'Pizzas artesanales', 3),
    (gen_random_uuid(), 'Tacos', 'Tacos mexicanos auténticos', 4),
    (gen_random_uuid(), 'Ensaladas', 'Frescas y saludables', 5),
    (gen_random_uuid(), 'Bebidas', 'Bebidas frías y calientes', 6),
    (gen_random_uuid(), 'Postres', 'Cierra con algo dulce', 7),
    (gen_random_uuid(), 'Desayunos', 'Comienza el día con energía', 8),
    (gen_random_uuid(), 'Botanas', 'Aperitivos para compartir', 9),
    (gen_random_uuid(), 'Antojitos Mexicanos', 'Lo mejor de México', 10),
    (gen_random_uuid(), 'Sopas', 'Sopas calientes y reconfortantes', 11),
    (gen_random_uuid(), 'Especialidades', 'Platillos especiales de la casa', 12),
    -- Additional categories for testing
    (gen_random_uuid(), 'Mariscos', 'Del mar a tu mesa', 13),
    (gen_random_uuid(), 'Carnes', 'Cortes premium y parrilladas', 14),
    (gen_random_uuid(), 'Pastas', 'Pastas italianas caseras', 15),
    (gen_random_uuid(), 'Sushi', 'Rollos y sashimi frescos', 16),
    (gen_random_uuid(), 'Vegetariano', 'Opciones plant-based', 17),
    (gen_random_uuid(), 'Kids Menu', 'Para los más pequeños', 18),
    (gen_random_uuid(), 'Cocteles', 'Bebidas con y sin alcohol', 19),
    (gen_random_uuid(), 'Cafetería', 'Café y repostería', 20)
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    display_order = EXCLUDED.display_order;
