import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001';

function App() {
  const [todos, setTodos] = useState([]);
  const [newTodo, setNewTodo] = useState({ title: '', description: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [token, setToken] = useState(localStorage.getItem('token') || null);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isRegister, setIsRegister] = useState(false);

  // Axios-Instanz mit Token
  const api = axios.create({
    baseURL: API_URL,
    headers: token ? { Authorization: `Bearer ${token}` } : {}
  });

  // Fetch todos from API
  const fetchTodos = async () => {
    if (!token) return;
    try {
      setLoading(true);
      const response = await api.get('/todos');
      setTodos(response.data);
      setError('');
    } catch (err) {
      setError('Failed to fetch todos');
      console.error('Error fetching todos:', err);
    } finally {
      setLoading(false);
    }
  };

  // Create new todo
  const createTodo = async (e) => {
    e.preventDefault();
    if (!newTodo.title.trim()) return;

    try {
      const response = await api.post('/todos', newTodo);
      setTodos([response.data, ...todos]);
      setNewTodo({ title: '', description: '' });
      setError('');
    } catch (err) {
      setError('Failed to create todo');
      console.error('Error creating todo:', err);
    }
  };

  // Toggle todo completion
  const toggleTodo = async (id, completed) => {
    try {
      const todo = todos.find(t => t.id === id);
      const response = await api.put(`/todos/${id}`, {
        ...todo,
        completed: !completed
      });
      setTodos(todos.map(t => t.id === id ? response.data : t));
      setError('');
    } catch (err) {
      setError('Failed to update todo');
      console.error('Error updating todo:', err);
    }
  };

  // Delete todo
  const deleteTodo = async (id) => {
    try {
      await api.delete(`/todos/${id}`);
      setTodos(todos.filter(t => t.id !== id));
      setError('');
    } catch (err) {
      setError('Failed to delete todo');
      console.error('Error deleting todo:', err);
    }
  };

  // Handle login/register
  const handleAuth = async (e) => {
    e.preventDefault();
    try {
      const endpoint = isRegister ? '/register' : '/login';
      const response = await axios.post(`${API_URL}${endpoint}`, {
        username,
        password
      });
      if (!isRegister) {
        localStorage.setItem('token', response.data.token);
        setToken(response.data.token);
        setError('');
        fetchTodos();
      } else {
        setIsRegister(false);
        setError('Registration successful. Please log in.');
      }
    } catch (err) {
      setError('Authentication failed');
      console.error('Auth error:', err);
    }
  };

  // Logout
  const handleLogout = () => {
    localStorage.removeItem('token');
    setToken(null);
    setTodos([]);
    setUsername('');
    setPassword('');
  };

  useEffect(() => {
    if (token) {
      fetchTodos();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  if (!token) {
    return (
      <div className="App">
        <div className="container auth-container">
          <h1>{isRegister ? 'Register' : 'Login'}</h1>
          {error && <div className="error">{error}</div>}
          <form onSubmit={handleAuth} className="auth-form">
            <input
              type="text"
              placeholder="Username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
            />
            <input
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
            <button type="submit">{isRegister ? 'Register' : 'Login'}</button>
          </form>
          <p>
            {isRegister ? 'Already have an account?' : "Don't have an account?"}{' '}
            <button
              className="link-btn"
              onClick={() => setIsRegister(!isRegister)}
            >
              {isRegister ? 'Login' : 'Register'}
            </button>
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="App">
      <div className="container">
        <h1>Todo App</h1>
        <button className="logout-btn" onClick={handleLogout}>
          Logout
        </button>

        {error && <div className="error">{error}</div>}

        <form onSubmit={createTodo} className="todo-form">
          <input
            type="text"
            placeholder="Todo title..."
            value={newTodo.title}
            onChange={(e) => setNewTodo({ ...newTodo, title: e.target.value })}
            required
          />
          <textarea
            placeholder="Description (optional)..."
            value={newTodo.description}
            onChange={(e) =>
              setNewTodo({ ...newTodo, description: e.target.value })
            }
            rows="3"
          />
          <button type="submit">Add Todo</button>
        </form>

        {loading ? (
          <div className="loading">Loading todos...</div>
        ) : (
          <div className="todo-list">
            {todos.length === 0 ? (
              <div className="empty-state">No todos yet. Add one above!</div>
            ) : (
              todos.map((todo) => (
                <div
                  key={todo.id}
                  className={`todo-item ${todo.completed ? 'completed' : ''}`}
                >
                  <div className="todo-content">
                    <h3>{todo.title}</h3>
                    {todo.description && <p>{todo.description}</p>}
                    <small>
                      Created: {new Date(todo.created_at).toLocaleString()}
                    </small>
                  </div>
                  <div className="todo-actions">
                    <button
                      onClick={() => toggleTodo(todo.id, todo.completed)}
                      className={`toggle-btn ${
                        todo.completed ? 'completed' : ''
                      }`}
                    >
                      {todo.completed ? '✓' : '○'}
                    </button>
                    <button
                      onClick={() => deleteTodo(todo.id)}
                      className="delete-btn"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default App;