-- Create todos table
CREATE TABLE IF NOT EXISTS todos (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_todos_created_at ON todos(created_at);
CREATE INDEX IF NOT EXISTS idx_todos_completed ON todos(completed);

-- Insert exsample data
INSERT INTO todos (title, description) VALUES
    ('Buy plant fertilizer', 'Help the balcony plants thrive before summer end'),
    ('Draft newsletter outline', 'Sketch the main points for this week email blast'),
    ('Call Grandma', 'Catch up and hear her stories from the family reunion'),
    ('Clean out junk drawer', 'Toss or organize the mysterious pile of odds and ends');

-- Update one todo as completed
UPDATE todos SET completed = TRUE WHERE title = 'Buy plant fertilizer';