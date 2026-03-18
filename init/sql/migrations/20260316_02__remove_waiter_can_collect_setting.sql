-- Remove legacy payment permission key superseded by canonical payments.* settings.
DELETE FROM pronto_system_settings
WHERE key = 'waiter_can_collect';
