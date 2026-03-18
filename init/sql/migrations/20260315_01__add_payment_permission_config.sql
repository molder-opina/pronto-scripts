-- Add payment permission configuration parameters
-- Date: 2026-03-15

-- Insert payment permission configuration settings with proper keys from CONFIG_CONTRACT
INSERT INTO pronto_system_settings (
    key, 
    value, 
    value_type, 
    description, 
    category,
    display_name
) VALUES
    ('payments.enable_cashier_role', 'true', 'boolean', 'Habilita el rol de cajero para operaciones de cobro.', 'business', 'Habilitar Rol Cajero'),
    ('payments.allow_waiter_cashier_operations', 'true', 'boolean', 'Permite a los meseros realizar operaciones de cobro.', 'business', 'Permitir Cobro por Meseros')
ON CONFLICT (key) DO NOTHING;

-- Add constraint to ensure at least one payment processor is enabled
-- This constraint will be enforced at application level since SQL constraints cannot easily handle this logic
-- The application must validate that not both values are false simultaneously