// Smart Expense Tracker Backend with Budget & Categories Support
// Install: npm install express cors jsonwebtoken body-parser sqlite3 nodemailer bcryptjs
// Run: node server.js

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bodyParser = require('body-parser');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');

const app = express();
const PORT = process.env.PORT || 3000;
const SECRET_KEY = 'your-super-secret-key-change-this-in-production';

const EMAIL_USER = 'smartexpensestrackerbd@gmail.com';
const EMAIL_PASS = 'elov wedj zgom tcqf';
const APP_URL = process.env.APP_URL || 'http://localhost:3000';

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: EMAIL_USER,
    pass: EMAIL_PASS,
  },
});

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(bodyParser.json());

// Initialize SQLite Database
const dbPath = path.join(__dirname, 'expense_tracker.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Database connection error:', err);
  } else {
    console.log('✅ Connected to SQLite database');
    initializeDatabase();
  }
});

function initializeDatabase() {
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      category TEXT NOT NULL,
      date TEXT NOT NULL,
      type TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS budgets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      category TEXT NOT NULL,
      amount REAL NOT NULL,
      period TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS custom_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      icon TEXT,
      color TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      token TEXT UNIQUE NOT NULL,
      expires_at DATETIME NOT NULL,
      used INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `);

  console.log('✅ Database tables initialized');
}

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Access token required' });
  jwt.verify(token, SECRET_KEY, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid or expired token' });
    req.user = user;
    next();
  });
};

// ============================================
// AUTHENTICATION ROUTES
// ============================================

// User Signup — bcrypt দিয়ে password hash করে save
app.post('/api/auth/signup', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password) {
    return res.status(400).json({ error: 'All fields are required' });
  }

  db.get('SELECT * FROM users WHERE email = ?', [email], async (err, existingUser) => {
    if (err) return res.status(500).json({ error: 'Database error' });
    if (existingUser) return res.status(400).json({ error: 'Email already registered' });

    try {
      const hashedPassword = await bcrypt.hash(password, 10);
      db.run(
        'INSERT INTO users (name, email, password) VALUES (?, ?, ?)',
        [name, email, hashedPassword],
        function(err) {
          if (err) return res.status(500).json({ error: 'Failed to create user' });
          const userId = this.lastID;
          const token = jwt.sign({ userId, email }, SECRET_KEY, { expiresIn: '30d' });
          res.status(201).json({ token, user: { id: userId, name, email } });
        }
      );
    } catch (e) {
      res.status(500).json({ error: 'Password hashing failed' });
    }
  });
});

// User Login — bcrypt দিয়ে password verify
app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  db.get('SELECT * FROM users WHERE email = ?', [email], async (err, user) => {
    if (err) return res.status(500).json({ error: 'Database error' });
    if (!user) return res.status(401).json({ error: 'Invalid email or password' });

    try {
      // bcrypt hash চেক — plain text হলেও fallback করবে (existing users এর জন্য)
      let passwordMatch = false;
      if (user.password.startsWith('$2')) {
        // bcrypt hashed password
        passwordMatch = await bcrypt.compare(password, user.password);
      } else {
        // plain text password (পুরনো users) — match করলে hash করে update করো
        passwordMatch = (password === user.password);
        if (passwordMatch) {
          // Auto-upgrade: plain text → bcrypt hash
          const hashedPassword = await bcrypt.hash(password, 10);
          db.run('UPDATE users SET password = ? WHERE id = ?', [hashedPassword, user.id]);
          console.log(`✅ Auto-upgraded password hash for user: ${email}`);
        }
      }

      if (!passwordMatch) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const token = jwt.sign(
        { userId: user.id, email: user.email },
        SECRET_KEY,
        { expiresIn: '30d' }
      );
      res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
    } catch (e) {
      res.status(500).json({ error: 'Authentication error' });
    }
  });
});

// Update Profile
app.put('/api/auth/update-profile', authenticateToken, (req, res) => {
  const { name } = req.body;
  const userId = req.user.userId;
  if (!name || name.trim() === '') return res.status(400).json({ error: 'Name is required' });
  db.run('UPDATE users SET name = ? WHERE id = ?', [name.trim(), userId], function(err) {
    if (err) return res.status(500).json({ error: 'Failed to update profile' });
    if (this.changes === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ success: true, message: 'Profile updated successfully', name: name.trim() });
  });
});

// ============================================
// FORGOT PASSWORD — Step 1
// ============================================
app.post('/api/auth/forgot-password', (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ message: 'Email is required' });

  db.get('SELECT * FROM users WHERE email = ?', [email], (err, user) => {
    if (err) return res.status(500).json({ message: 'Database error' });
    if (!user) {
      return res.status(200).json({ message: 'If this email exists, a reset link has been sent' });
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    db.run('DELETE FROM password_reset_tokens WHERE user_id = ? AND used = 0', [user.id], () => {
      db.run(
        'INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES (?, ?, ?)',
        [user.id, resetToken, expiresAt.toISOString()],
        (err) => {
          if (err) return res.status(500).json({ message: 'Failed to create reset token' });

          const resetLink = `${APP_URL}/api/auth/reset-password-page?token=${resetToken}`;

          const mailOptions = {
            from: `"Smart Expense Tracker" <${EMAIL_USER}>`,
            to: email,
            subject: 'Password Reset Request',
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 500px; margin: auto; padding: 24px; border: 1px solid #eee; border-radius: 12px;">
                <h2 style="color: #333;">Password Reset</h2>
                <p style="color: #555;">আপনার Smart Expense Tracker account এর password reset করতে নিচের button এ click করুন।</p>
                <a href="${resetLink}" 
                   style="display: inline-block; margin: 20px 0; padding: 12px 28px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 8px; font-size: 16px;">
                  Reset Password
                </a>
                <p style="color: #999; font-size: 13px;">এই link টি <strong>১ ঘণ্টা</strong> পর expire হয়ে যাবে।</p>
                <p style="color: #999; font-size: 13px;">আপনি যদি password reset request না করে থাকেন, এই email টি ignore করুন।</p>
                <hr style="border: none; border-top: 1px solid #eee; margin-top: 24px;">
                <p style="color: #ccc; font-size: 11px;">Smart Expense Tracker</p>
              </div>
            `,
          };

          transporter.sendMail(mailOptions, (mailErr) => {
            if (mailErr) {
              console.error('Email send error:', mailErr);
              return res.status(500).json({ message: 'Failed to send email. Check email config.' });
            }
            console.log(`✅ Password reset email sent to: ${email}`);
            res.status(200).json({ message: 'Reset link sent successfully' });
          });
        }
      );
    });
  });
});

// Reset password page (browser এ খুলবে)
app.get('/api/auth/reset-password-page', (req, res) => {
  const { token } = req.query;
  if (!token) {
    return res.send(`
      <div style="font-family:Arial,sans-serif;text-align:center;padding:60px;">
        <h2 style="color:red;">❌ Invalid Link</h2>
        <p>Reset link টি valid নয়।</p>
      </div>
    `);
  }

  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Reset Password</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
        .card { background: white; padding: 32px; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); width: 100%; max-width: 400px; }
        h2 { color: #333; margin-bottom: 8px; }
        p  { color: #777; font-size: 14px; margin-bottom: 24px; }
        input { width: 100%; padding: 12px 16px; border: 1px solid #ddd; border-radius: 8px; font-size: 15px; margin-bottom: 12px; outline: none; }
        input:focus { border-color: #4CAF50; }
        button { width: 100%; padding: 14px; background: #4CAF50; color: white; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; }
        button:hover { background: #43A047; }
        .msg { margin-top: 16px; padding: 12px; border-radius: 8px; font-size: 14px; text-align: center; display: none; }
        .success { background: #e8f5e9; color: #2e7d32; }
        .error   { background: #ffebee; color: #c62828; }
      </style>
    </head>
    <body>
      <div class="card">
        <h2>🔒 Reset Password</h2>
        <p>নতুন password দিন</p>
        <input type="password" id="password" placeholder="নতুন password" />
        <input type="password" id="confirm" placeholder="password আবার দিন" />
        <button onclick="resetPassword()">Password Reset করুন</button>
        <div id="msg" class="msg"></div>
      </div>
      <script>
        async function resetPassword() {
          const password = document.getElementById('password').value;
          const confirm  = document.getElementById('confirm').value;
          const msg      = document.getElementById('msg');
          msg.style.display = 'none';
          if (!password || password.length < 6) {
            msg.className = 'msg error';
            msg.textContent = 'Password কমপক্ষে ৬ character হতে হবে';
            msg.style.display = 'block';
            return;
          }
          if (password !== confirm) {
            msg.className = 'msg error';
            msg.textContent = 'Password দুটো মিলছে না';
            msg.style.display = 'block';
            return;
          }
          const res = await fetch('/api/auth/reset-password', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ token: '${token}', newPassword: password })
          });
          const data = await res.json();
          if (res.ok) {
            msg.className = 'msg success';
            msg.textContent = '✅ Password সফলভাবে reset হয়েছে! App এ login করুন।';
            msg.style.display = 'block';
            document.querySelector('button').disabled = true;
          } else {
            msg.className = 'msg error';
            msg.textContent = data.message || 'কিছু একটা সমস্যা হয়েছে।';
            msg.style.display = 'block';
          }
        }
      </script>
    </body>
    </html>
  `);
});

// Reset password API — bcrypt দিয়ে hash করে save
app.post('/api/auth/reset-password', async (req, res) => {
  const { token, newPassword } = req.body;
  if (!token || !newPassword) return res.status(400).json({ message: 'Token and new password are required' });
  if (newPassword.length < 6) return res.status(400).json({ message: 'Password must be at least 6 characters' });

  db.get(
    `SELECT * FROM password_reset_tokens WHERE token = ? AND used = 0 AND expires_at > datetime('now')`,
    [token],
    async (err, resetEntry) => {
      if (err) return res.status(500).json({ message: 'Database error' });
      if (!resetEntry) return res.status(400).json({ message: 'Reset link টি expire হয়ে গেছে বা invalid।' });

      try {
        const hashedPassword = await bcrypt.hash(newPassword, 10);
        db.run('UPDATE users SET password = ? WHERE id = ?', [hashedPassword, resetEntry.user_id], (err) => {
          if (err) return res.status(500).json({ message: 'Failed to update password' });
          db.run('UPDATE password_reset_tokens SET used = 1 WHERE id = ?', [resetEntry.id]);
          console.log(`✅ Password reset successful for user_id: ${resetEntry.user_id}`);
          res.json({ message: 'Password successfully reset' });
        });
      } catch (e) {
        res.status(500).json({ message: 'Password hashing failed' });
      }
    }
  );
});

// ============================================
// TRANSACTION ROUTES
// ============================================

app.get('/api/transactions', authenticateToken, (req, res) => {
  const { type } = req.query;
  let query = 'SELECT * FROM transactions WHERE user_id = ?';
  const params = [req.user.userId];
  if (type) { query += ' AND type = ?'; params.push(type); }
  query += ' ORDER BY date DESC';
  db.all(query, params, (err, transactions) => {
    if (err) return res.status(500).json({ error: 'Database error' });
    res.json(transactions);
  });
});

app.get('/api/transactions/summary', authenticateToken, (req, res) => {
  db.all(
    'SELECT type, SUM(amount) as total FROM transactions WHERE user_id = ? GROUP BY type',
    [req.user.userId],
    (err, results) => {
      if (err) return res.status(500).json({ error: 'Database error' });
      let totalIncome = 0, totalExpense = 0;
      results.forEach(row => {
        if (row.type === 'income') totalIncome = row.total;
        else if (row.type === 'expense') totalExpense = row.total;
      });
      res.json({ totalIncome, totalExpense, balance: totalIncome - totalExpense });
    }
  );
});

app.post('/api/transactions', authenticateToken, (req, res) => {
  const { title, amount, category, date, type } = req.body;
  if (!title || !amount || !category || !type) return res.status(400).json({ error: 'All fields are required' });
  if (!['income', 'expense'].includes(type)) return res.status(400).json({ error: 'Type must be income or expense' });
  const transactionDate = date || new Date().toISOString();
  db.run(
    'INSERT INTO transactions (user_id, title, amount, category, date, type) VALUES (?, ?, ?, ?, ?, ?)',
    [req.user.userId, title, amount, category, transactionDate, type],
    function(err) {
      if (err) return res.status(500).json({ error: 'Failed to create transaction' });
      res.status(201).json({ id: this.lastID, user_id: req.user.userId, title, amount, category, date: transactionDate, type });
    }
  );
});

app.put('/api/transactions/:id', authenticateToken, (req, res) => {
  const { id } = req.params;
  const { title, amount, category, date, type } = req.body;
  db.get('SELECT * FROM transactions WHERE id = ? AND user_id = ?', [id, req.user.userId], (err, transaction) => {
    if (err) return res.status(500).json({ error: 'Database error' });
    if (!transaction) return res.status(404).json({ error: 'Transaction not found' });
    const updates = {
      title: title || transaction.title,
      amount: amount || transaction.amount,
      category: category || transaction.category,
      date: date || transaction.date,
      type: type || transaction.type
    };
    db.run(
      'UPDATE transactions SET title = ?, amount = ?, category = ?, date = ?, type = ? WHERE id = ?',
      [updates.title, updates.amount, updates.category, updates.date, updates.type, id],
      (err) => {
        if (err) return res.status(500).json({ error: 'Failed to update transaction' });
        res.json({ id, ...updates });
      }
    );
  });
});

app.delete('/api/transactions/:id', authenticateToken, (req, res) => {
  const { id } = req.params;
  db.run('DELETE FROM transactions WHERE id = ? AND user_id = ?', [id, req.user.userId], function(err) {
    if (err) return res.status(500).json({ error: 'Database error' });
    if (this.changes === 0) return res.status(404).json({ error: 'Transaction not found' });
    res.json({ success: true, message: 'Transaction deleted successfully' });
  });
});

// ============================================
// BUDGET ROUTES
// ============================================

app.get('/api/budgets', authenticateToken, (req, res) => {
  db.all('SELECT * FROM budgets WHERE user_id = ? ORDER BY created_at DESC', [req.user.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: 'Database error' });
    res.json(rows);
  });
});

app.get('/api/budgets/status', authenticateToken, (req, res) => {
  const userId = req.user.userId;
  db.all('SELECT * FROM budgets WHERE user_id = ?', [userId], (err, budgets) => {
    if (err) return res.status(500).json({ error: 'Database error' });
    const promises = budgets.map(budget => {
      return new Promise((resolve) => {
        const now = new Date();
        const startDate = budget.period === 'monthly'
          ? new Date(now.getFullYear(), now.getMonth(), 1)
          : new Date(now.getFullYear(), 0, 1);
        db.get(
          'SELECT SUM(amount) as spent FROM transactions WHERE user_id = ? AND category = ? AND type = "expense" AND date >= ?',
          [userId, budget.category, startDate.toISOString()],
          (err, row) => { resolve({ budget, spent: row?.spent || 0 }); }
        );
      });
    });
    Promise.all(promises).then(results => res.json(results));
  });
});

app.post('/api/budgets', authenticateToken, (req, res) => {
  const { category, amount, period } = req.body;
  if (!category || !amount || !period) return res.status(400).json({ error: 'Missing required fields' });
  db.run(
    'INSERT INTO budgets (user_id, category, amount, period) VALUES (?, ?, ?, ?)',
    [req.user.userId, category, amount, period],
    function(err) {
      if (err) return res.status(500).json({ error: 'Database error' });
      res.status(201).json({ id: this.lastID, message: 'Budget created successfully' });
    }
  );
});

app.put('/api/budgets/:id', authenticateToken, (req, res) => {
  const { id } = req.params;
  const { category, amount, period } = req.body;
  db.run(
    'UPDATE budgets SET category = ?, amount = ?, period = ? WHERE id = ? AND user_id = ?',
    [category, amount, period, id, req.user.userId],
    function(err) {
      if (err) return res.status(500).json({ error: 'Database error' });
      if (this.changes === 0) return res.status(404).json({ error: 'Budget not found' });
      res.json({ message: 'Budget updated successfully' });
    }
  );
});

app.delete('/api/budgets/:id', authenticateToken, (req, res) => {
  const { id } = req.params;
  db.run('DELETE FROM budgets WHERE id = ? AND user_id = ?', [id, req.user.userId], function(err) {
    if (err) return res.status(500).json({ error: 'Database error' });
    if (this.changes === 0) return res.status(404).json({ error: 'Budget not found' });
    res.json({ message: 'Budget deleted successfully' });
  });
});

// ============================================
// CUSTOM CATEGORIES ROUTES
// ============================================

app.get('/api/categories', authenticateToken, (req, res) => {
  db.all('SELECT * FROM custom_categories WHERE user_id = ? ORDER BY created_at DESC', [req.user.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: 'Database error' });
    res.json(rows);
  });
});

app.post('/api/categories', authenticateToken, (req, res) => {
  const { name, type, icon, color } = req.body;
  if (!name || !type) return res.status(400).json({ error: 'Missing required fields' });
  db.run(
    'INSERT INTO custom_categories (user_id, name, type, icon, color) VALUES (?, ?, ?, ?, ?)',
    [req.user.userId, name, type, icon, color],
    function(err) {
      if (err) return res.status(500).json({ error: 'Database error' });
      res.status(201).json({ id: this.lastID, message: 'Category created successfully' });
    }
  );
});

app.put('/api/categories/:id', authenticateToken, (req, res) => {
  const { id } = req.params;
  const { name, type, icon, color } = req.body;
  db.run(
    'UPDATE custom_categories SET name = ?, type = ?, icon = ?, color = ? WHERE id = ? AND user_id = ?',
    [name, type, icon, color, id, req.user.userId],
    function(err) {
      if (err) return res.status(500).json({ error: 'Database error' });
      if (this.changes === 0) return res.status(404).json({ error: 'Category not found' });
      res.json({ message: 'Category updated successfully' });
    }
  );
});

app.delete('/api/categories/:id', authenticateToken, (req, res) => {
  const { id } = req.params;
  db.get(
    `SELECT COUNT(*) as count FROM transactions t
     JOIN custom_categories c ON t.category = c.name
     WHERE c.id = ? AND c.user_id = ?`,
    [id, req.user.userId],
    (err, row) => {
      if (err) return res.status(500).json({ error: 'Database error' });
      if (row.count > 0) return res.status(400).json({ error: 'Cannot delete category that is being used' });
      db.run('DELETE FROM custom_categories WHERE id = ? AND user_id = ?', [id, req.user.userId], function(err) {
        if (err) return res.status(500).json({ error: 'Database error' });
        if (this.changes === 0) return res.status(404).json({ error: 'Category not found' });
        res.json({ message: 'Category deleted successfully' });
      });
    }
  );
});

// ============================================
// UTILITY ROUTES
// ============================================

app.get('/api/health', (req, res) => {
  db.get('SELECT COUNT(*) as userCount FROM users', (err, userResult) => {
    db.get('SELECT COUNT(*) as transactionCount FROM transactions', (err2, transactionResult) => {
      res.json({
        status: 'OK',
        timestamp: new Date(),
        database: 'SQLite',
        users: userResult ? userResult.userCount : 0,
        transactions: transactionResult ? transactionResult.transactionCount : 0
      });
    });
  });
});

// ============================================
// START SERVER
// ============================================

app.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   🚀 Smart Expense Tracker API Server                ║
║                                                       ║
║   Server running on port: ${PORT}                    ║
║   Password Security: bcrypt ✅                        ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
  `);
});

process.on('SIGINT', () => {
  db.close((err) => {
    process.exit(0);
  });
});