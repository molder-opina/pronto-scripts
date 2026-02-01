# Scripts de Seed para Pronto

Este directorio contiene todos los scripts para poblar y gestionar la base de datos de Pronto.

## Script Maestro

### seed_all.py
Script principal que pobla toda la base de datos con datos de prueba.

```bash
# Seed completo
python seeds/seed_all.py

# Seed borrando datos existentes
python seeds/seed_all.py --reset

# Seed sin empleados
python seeds/seed_all.py --skip-employees

# Seed sin clientes
python seeds/seed_all.py --skip-customers
```

## Scripts Individuales por Recurso

### seed_products.py - Productos del Menú
```bash
# Listar productos
python seeds/seed_products.py --action list

# Agregar producto
python seeds/seed_products.py --action add --name "Hamburguesa Clasica" --price 7.50 --category "Hamburguesas"

# Actualizar producto
python seeds/seed_products.py --action update --id 1 --price 8.00

# Eliminar producto
python seeds/seed_products.py --action delete --id 1

# Buscar producto
python seeds/seed_products.py --action search --search "hamburguesa"
```

### seed_customers.py - Clientes
```bash
# Listar clientes
python seeds/seed_customers.py --action list

# Agregar cliente
python seeds/seed_customers.py --action add --name "Juan Perez" --email "juan@email.com" --phone "+34600000000"

# Actualizar cliente
python seeds/seed_customers.py --action update --id 1 --name "Juan Garcia"

# Eliminar cliente
python seeds/seed_customers.py --action delete --id 1

# Buscar cliente
python seeds/seed_customers.py --action search --search "juan"
```

### seed_employees.py - Empleados
```bash
# Listar empleados
python seeds/seed_employees.py --action list

# Agregar empleado
python seeds/seed_employees.py --action add --name "Maria" --email "maria@email.com" --role "waiter"

# Actualizar empleado
python seeds/seed_employees.py --action update --id 1 --role "chef"

# Eliminar empleado
python seeds/seed_employees.py --action delete --id 1

# Buscar empleado
python seeds/seed_employees.py --action search --search "maria"
```

### seed_categories.py - Categorías del Menú
```bash
# Listar categorías
python seeds/seed_categories.py --action list

# Agregar categoría
python seeds/seed_categories.py --action add --name "Postres" --description "Dulces y pasteles" --order 7

# Actualizar categoría
python seeds/seed_categories.py --action update --id 1 --name "Bebidas"

# Eliminar categoría
python seeds/seed_categories.py --action delete --id 1
```

### seed_modifier_groups.py - Grupos de Modificadores
```bash
# Listar grupos
python seeds/seed_modifier_groups.py --action list

# Agregar grupo
python seeds/seed_modifier_groups.py --action add --name "Queso Extra" --min 0 --max 3 --required false

# Actualizar grupo
python seeds/seed_modifier_groups.py --action update --id 1 --max 5

# Eliminar grupo
python seeds/seed_modifier_groups.py --action delete --id 1
```

### seed_modifiers.py - Aditamentos/Modificadores
```bash
# Listar modificadores
python seeds/seed_modifiers.py --action list

# Agregar modificador
python seeds/seed_modifiers.py --action add --name "Queso Cheddar" --group "Queso Extra" --price 1.50

# Actualizar modificador
python seeds/seed_modifiers.py --action update --id 1 --price 2.00

# Eliminar modificador
python seeds/seed_modifiers.py --action delete --id 1
```

### seed_tables.py - Mesas
```bash
# Listar mesas
python seeds/seed_tables.py --action list

# Agregar mesa
python seeds/seed_tables.py --action add --number "1" --area "Terraza" --capacity 4

# Actualizar mesa
python seeds/seed_tables.py --action update --id 1 --capacity 6

# Generar códigos QR
python seeds/seed_tables.py --action generate-qr
```

### seed_areas.py - Áreas
```bash
# Listar áreas
python seeds/seed_areas.py --action list

# Agregar área
python seeds/seed_areas.py --action add --name "Terraza" --prefix "TZ" --color "#ff6b35"

# Actualizar área
python seeds/seed_areas.py --action update --id 1 --color "#00ff00"

# Eliminar área
python seeds/seed_areas.py --action delete --id 1
```

### seed_configs.py - Configuraciones del Negocio
```bash
# Listar configuraciones
python seeds/seed_configs.py --action list

# Actualizar configuración
python seeds/seed_configs.py --action update --key "tax_rate" --value 16.0

# Resetear a valores por defecto
python seeds/seed_configs.py --action reset
```

## Contraseña por Defecto

Los empleados se crean con la contraseña por defecto configurada en la variable de entorno `SEED_EMPLOYEE_PASSWORD` o `ChangeMe!123` por defecto.

## Modelos Incluidos

- **Áreas**: Zonas del restaurante (Terraza, Comedor Principal, Barra, etc.)
- **Mesas**: Mesas con códigos QR para pedidos
- **Categorías**: Categorías del menú (Hamburguesas, Pizzas, Bebidas, etc.)
- **Productos**: Items del menú con precios y tiempos de preparación
- **Grupos de Modificadores**: Grupos como "Queso Extra", "Salsas", etc.
- **Modificadores**: Opciones individuales dentro de cada grupo
- **Configuraciones**: Ajustes del negocio (tax_rate, restaurant_name, etc.)
- **Empleados**: Usuarios con roles (admin, waiter, chef, cashier)
- **Clientes**: Clientes registrados con email y teléfono
