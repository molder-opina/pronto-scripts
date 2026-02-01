-- MenuCategory: Categorías del menú
CREATE TABLE IF NOT EXISTS pronto_menu_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE,
    description TEXT,
    display_order INTEGER NOT NULL DEFAULT 0
);

-- MenuItem: Productos del menú
CREATE TABLE IF NOT EXISTS pronto_menu_items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    image_path VARCHAR(255),
    category_id INTEGER NOT NULL REFERENCES pronto_menu_categories(id),
    preparation_time_minutes INTEGER DEFAULT 15,
    is_breakfast_recommended BOOLEAN NOT NULL DEFAULT FALSE,
    is_afternoon_recommended BOOLEAN NOT NULL DEFAULT FALSE,
    is_night_recommended BOOLEAN NOT NULL DEFAULT FALSE,
    track_inventory BOOLEAN NOT NULL DEFAULT FALSE,
    stock_quantity INTEGER,
    low_stock_threshold INTEGER DEFAULT 10,
    is_quick_serve BOOLEAN NOT NULL DEFAULT FALSE
);
