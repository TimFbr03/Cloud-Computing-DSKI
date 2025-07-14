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

-- Insert sample data
INSERT INTO todos (title, description) VALUES
    ('Setup development environment', 'Install Docker and configure the microservices'),
    ('Create database schema', 'Design and implement the PostgreSQL database structure'),
    ('Build REST API', 'Develop the backend API with Node.js and Express'),
    ('Design frontend UI', 'Create a responsive React frontend for the todo app');

-- Update one todo as completed
UPDATE todos SET completed = TRUE WHERE title = 'Setup development environment';