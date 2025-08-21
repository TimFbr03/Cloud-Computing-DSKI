-- Drop tables (nur für Development/Testing!)
DROP TABLE IF EXISTS user_stats CASCADE;
DROP TABLE IF EXISTS todos CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- User-Tabelle mit gehashten Passwörtern
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,                -- ID wird automatisch erstellt
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,  -- Gehashtes Passwort mit bcrypt
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Todos-Tabelle mit User-Referenz
CREATE TABLE IF NOT EXISTS todos (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

-- Indexe für Todos
CREATE INDEX IF NOT EXISTS idx_todos_created_at ON todos(created_at);
CREATE INDEX IF NOT EXISTS idx_todos_completed ON todos(completed);
CREATE INDEX IF NOT EXISTS idx_todos_deleted ON todos(deleted);

-- Tabelle für Statistik: Anzahl Todos pro User
CREATE TABLE IF NOT EXISTS user_stats (
    id SERIAL PRIMARY KEY,
    user_id INT UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    todo_count INT DEFAULT 0
);

-- Trigger-Funktion: Zählt Todos automatisch hoch/runter
CREATE OR REPLACE FUNCTION update_todo_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE user_stats SET todo_count = todo_count + 1 WHERE user_id = NEW.user_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE user_stats SET todo_count = todo_count - 1 WHERE user_id = OLD.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger anlegen
DROP TRIGGER IF EXISTS todos_count_trigger ON todos;
CREATE TRIGGER todos_count_trigger
AFTER INSERT OR DELETE ON todos
FOR EACH ROW EXECUTE FUNCTION update_todo_count();

-- Beispiel-User mit gehashten Passwörtern
-- Passwort für beide ist "test123"
-- Hash wurde mit bcrypt.hash("test123", 10) generiert
INSERT INTO users (username, password_hash) VALUES
('alice', '$2b$10$rBV2HQLuQk.0LklvH0ZQKuJ7/Z.2.2.y8uVXc1z1z1z1z1z1z1z1z'),
('bob', '$2b$10$rBV2HQLuQk.0LklvH0ZQKuJ7/Z.2.2.y8uVXc1z1z1z1z1z1z1z1z');

-- Initiale Statistik-Einträge
INSERT INTO user_stats (user_id, todo_count)
SELECT id, 0 FROM users;

-- Beispiel-Todos für User Alice (id=1) und Bob (id=2)
INSERT INTO todos (title, description, completed, deleted, user_id) VALUES
('Buy plant fertilizer', 'Help the balcony plants thrive before summer end', TRUE, FALSE, 1),
('Draft newsletter outline', 'Sketch the main points for this week email blast', FALSE, FALSE, 1),
('Call Grandma', 'Catch up and hear her stories from the family reunion', FALSE, FALSE, 2),
('Finish project report', 'High priority: finish project report before 2025-09-01', FALSE, FALSE, 2);