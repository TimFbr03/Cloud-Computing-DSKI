const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Test database connection
pool.connect()
  .then(() => console.log('Connected to PostgreSQL database'))
  .catch(err => console.error('Database connection error:', err));

// Routes

// Get all todos
app.get('/api/todos', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM todos ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching todos:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get single todo
app.get('/api/todos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM todos WHERE id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Todo not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error fetching todo:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new todo
app.post('/api/todos', async (req, res) => {
  try {
    const { title, description } = req.body;
    
    if (!title) {
      return res.status(400).json({ error: 'Title is required' });
    }
    
    const result = await pool.query(
      'INSERT INTO todos (title, description) VALUES ($1, $2) RETURNING *',
      [title, description || '']
    );
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating todo:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update todo
app.put('/api/todos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, completed } = req.body;
    
    const result = await pool.query(
      'UPDATE todos SET title = $1, description = $2, completed = $3, updated_at = CURRENT_TIMESTAMP WHERE id = $4 RETURNING *',
      [title, description, completed, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Todo not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating todo:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete todo
app.delete('/api/todos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('DELETE FROM todos WHERE id = $1 RETURNING *', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Todo not found' });
    }
    
    res.json({ message: 'Todo deleted successfully' });
  } catch (err) {
    console.error('Error deleting todo:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.listen(port, () => {
  console.log(`Todo API server running on port ${port}`);
});