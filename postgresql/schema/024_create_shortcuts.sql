-- KeyboardShortcut: Atajos de teclado
CREATE TABLE IF NOT EXISTS pronto_keyboard_shortcuts (
    id SERIAL PRIMARY KEY,
    combo VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'General',
    callback_function VARCHAR(100) NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    prevent_default BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_shortcut_combo ON pronto_keyboard_shortcuts(combo);
CREATE INDEX IF NOT EXISTS ix_shortcut_enabled ON pronto_keyboard_shortcuts(is_enabled);
