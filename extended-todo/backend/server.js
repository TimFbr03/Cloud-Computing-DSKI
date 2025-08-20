const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs'); // Geändert von 'bcrypt' zu 'bcryptjs'
const jwt = require('jsonwebtoken');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3001;
const SECRET = process.env.JWT_SECRET || "supersecret";

// Middleware
app.use(cors({
  origin: true, // Allow all origins in development
  credentials: true
}));
app.use(express.json());

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Test DB
pool.connect()
  .then(() => console.log('Connected to PostgreSQL database'))
  .catch(err => console.error('Database connection error:', err));

// Auth middleware
function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.sendStatus(401);
  const token = authHeader.split(' ')[1];
  jwt.verify(token, SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
}

// Register
app.post('/register', async (req, res) => {
  const { username, password } = req.body;
  
  // Validierung
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }
  
  if (password.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters long' });
  }
  
  try {
    const hash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      'INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id, username',
      [username, hash]
    );
    const user = result.rows[0];
    // init stats row
    await pool.query(
      'INSERT INTO user_stats (user_id, todo_count) VALUES ($1, 0)',
      [user.id]
    );
    res.status(201).json({ message: 'User created successfully', user });
  } catch (err) {
    console.error("Register error:", err);
    if (err.code === '23505') { // PostgreSQL unique violation
      res.status(400).json({ error: 'Username already exists' });
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

// Login
app.post('/login', async (req, res) => {
  const { username, password } = req.body;
  console.log("Login attempt:", { username, password }); // Debug!

  try {
    const result = await pool.query('SELECT * FROM users WHERE username=$1', [username]);
    if (result.rows.length === 0) {
      console.log("No user found for", username);
      return res.sendStatus(401);
    }

    const user = result.rows[0];
    console.log("User from DB:", user);

    const match = await bcrypt.compare(password, user.password_hash);
    console.log("Password match?", match);

    if (!match) return res.sendStatus(401);

    const token = jwt.sign({ id: user.id, username: user.username }, SECRET, { expiresIn: '1h' });
    res.json({ token });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Todos (nur für eingeloggte User)
app.get('/todos', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM todos WHERE user_id=$1 ORDER BY created_at DESC',
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching todos:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/todos', authMiddleware, async (req, res) => {
  try {
    const { title, description } = req.body;
    if (!title) return res.status(400).json({ error: 'Title is required' });

    const result = await pool.query(
      'INSERT INTO todos (title, description, user_id) VALUES ($1, $2, $3) RETURNING *',
      [title, description || '', req.user.id]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating todo:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.put('/todos/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, completed } = req.body;

    const result = await pool.query(
      'UPDATE todos SET title=$1, description=$2, completed=$3, updated_at=CURRENT_TIMESTAMP WHERE id=$4 AND user_id=$5 RETURNING *',
      [title, description, completed, id, req.user.id]
    );

    if (result.rows.length === 0) return res.status(404).json({ error: 'Todo not found' });

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating todo:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/todos/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      'DELETE FROM todos WHERE id=$1 AND user_id=$2 RETURNING *',
      [id, req.user.id]
    );

    if (result.rows.length === 0) return res.status(404).json({ error: 'Todo not found' });

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

app.listen(port, '0.0.0.0', () => {
  console.log(`Todo API server running on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Database URL: ${process.env.DATABASE_URL ? 'Set' : 'Not set'}`);
});