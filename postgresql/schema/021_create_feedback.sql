-- Feedback: Feedback de clientes
CREATE TABLE IF NOT EXISTS pronto_feedback (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES pronto_dining_sessions(id),
    customer_id INTEGER REFERENCES pronto_customers(id),
    employee_id INTEGER REFERENCES pronto_employees(id),
    category VARCHAR(50) NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_feedback_session ON pronto_feedback(session_id);
CREATE INDEX IF NOT EXISTS ix_feedback_employee ON pronto_feedback(employee_id);
CREATE INDEX IF NOT EXISTS ix_feedback_category ON pronto_feedback(category);
CREATE INDEX IF NOT EXISTS ix_feedback_rating ON pronto_feedback(rating);
CREATE INDEX IF NOT EXISTS ix_feedback_created_at ON pronto_feedback(created_at);

-- FeedbackQuestion: Preguntas de feedback
CREATE TABLE IF NOT EXISTS pronto_feedback_questions (
    id SERIAL PRIMARY KEY,
    question_text TEXT NOT NULL,
    question_type VARCHAR(20) NOT NULL DEFAULT 'rating',
    category VARCHAR(50),
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    min_rating INTEGER NOT NULL DEFAULT 1,
    max_rating INTEGER NOT NULL DEFAULT 5,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_feedback_question_enabled ON pronto_feedback_questions(is_enabled);
CREATE INDEX IF NOT EXISTS ix_feedback_question_order ON pronto_feedback_questions(sort_order);

-- FeedbackToken: Tokens para feedback
CREATE TABLE IF NOT EXISTS pronto_feedback_tokens (
    id SERIAL PRIMARY KEY,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    order_id INTEGER NOT NULL REFERENCES pronto_orders(id) ON DELETE CASCADE,
    session_id INTEGER NOT NULL REFERENCES pronto_dining_sessions(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES pronto_customers(id) ON DELETE CASCADE,
    email VARCHAR(255),
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    email_sent_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_feedback_token_order ON pronto_feedback_tokens(order_id);
CREATE INDEX IF NOT EXISTS ix_feedback_token_session ON pronto_feedback_tokens(session_id);
CREATE INDEX IF NOT EXISTS ix_feedback_token_user ON pronto_feedback_tokens(user_id);
CREATE INDEX IF NOT EXISTS ix_feedback_token_hash ON pronto_feedback_tokens(token_hash);
CREATE INDEX IF NOT EXISTS ix_feedback_token_expires ON pronto_feedback_tokens(expires_at);
CREATE INDEX IF NOT EXISTS ix_feedback_token_used ON pronto_feedback_tokens(used_at);
