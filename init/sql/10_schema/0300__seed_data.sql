-- Seed data para PRONTO

-- Insertar empleados
INSERT INTO pronto_employees (employee_code, first_name, last_name, email, pin, role, department, status) VALUES
('EMP001', 'Juan', 'Pérez', 'juan@pronto.com', '1234', 'admin', 'Management', 'active'),
('EMP002', 'María', 'García', 'maria@pronto.com', '2345', 'waiter', 'Service', 'active'),
('EMP003', 'Carlos', 'López', 'carlos@pronto.com', '3456', 'chef', 'Kitchen', 'active'),
('EMP004', 'Ana', 'Martínez', 'ana@pronto.com', '4567', 'waiter', 'Service', 'active'),
('EMP005', 'Pedro', 'Sánchez', 'pedro@pronto.com', '5678', 'cashier', 'Front', 'active');

-- Insertar mesas
INSERT INTO pronto_tables (table_number, area_id, capacity, status) VALUES
('T1', (SELECT id FROM pronto_areas WHERE name = 'Main Floor'), 4, 'available'),
('T2', (SELECT id FROM pronto_areas WHERE name = 'Main Floor'), 4, 'available'),
('T3', (SELECT id FROM pronto_areas WHERE name = 'Main Floor'), 6, 'available'),
('T4', (SELECT id FROM pronto_areas WHERE name = 'Patio'), 4, 'available'),
('T5', (SELECT id FROM pronto_areas WHERE name = 'Patio'), 6, 'available'),
('T6', (SELECT id FROM pronto_areas WHERE name = 'Bar'), 2, 'available'),
('T7', (SELECT id FROM pronto_areas WHERE name = 'Bar'), 2, 'available'),
('T8', (SELECT id FROM pronto_areas WHERE name = 'Private Room'), 10, 'available');

-- Insertar items del menú
INSERT INTO pronto_menu_items (name, description, price, category_id, preparation_time_minutes, is_available) VALUES
('Crispy Calamari', 'Calamares fritos con salsa tártara', 12.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Appetizers'), 10, true),
('Bruschetta', 'Pan tostado con tomate, albahaca y aceite de oliva', 9.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Appetizers'), 8, true),
('Caesar Salad', 'Lechuga romana, croutones, parmesano', 11.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Appetizers'), 5, true),
('Grilled Chicken Burger', 'Pollo a la parrilla, lechuga, tomate, mayo', 14.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Main Courses'), 15, true),
('Beef Steak', 'Bistec de res 200g con papas', 24.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Main Courses'), 20, true),
('Fish Tacos', 'Tacos de pescado con salsa de mango', 13.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Main Courses'), 12, true),
('Pasta Carbonara', 'Pasta con salsa cremosa de tocino', 15.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Main Courses'), 15, true),
('Chocolate Lava Cake', 'Pastel de chocolate con centro fundido', 8.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Desserts'), 12, true),
('Cheesecake', 'Cheesecake de fresa', 7.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Desserts'), 5, true),
('Ice Cream', 'Helado de vainilla o chocolate', 4.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Desserts'), 3, true),
('Coffee', 'Café americano', 2.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Beverages'), 2, true),
('Fresh Juice', 'Jugo natural de naranja', 3.99, (SELECT id FROM pronto_menu_categories WHERE name = 'Beverages'), 3, true),
('Soft Drink', 'Refresco de cola', 2.49, (SELECT id FROM pronto_menu_categories WHERE name = 'Beverages'), 1, true);

-- Insertar clientes de prueba
INSERT INTO pronto_customers (first_name, last_name, email, phone, loyalty_points) VALUES
('Roberto', 'Gómez', 'roberto@email.com', '555-0101', 150),
('Laura', 'Díaz', 'laura@email.com', '555-0102', 320),
('Miguel', 'Fernández', 'miguel@email.com', '555-0103', 75);
