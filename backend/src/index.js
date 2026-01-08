const express = require('express');
const { createServer } = require('http');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
require('dotenv').config();

const logger = require('./utils/logger');
const { pool } = require('./config/database');
const { createRedisClient } = require('./config/redis');
const { initializeWebSocket } = require('./websocket');
const { runMigrations } = require('./migrations');

// Routes
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const chatRoutes = require('./routes/chats');
const messageRoutes = require('./routes/messages');
const contactRoutes = require('./routes/contacts');
const callRoutes = require('./routes/calls');
const mediaRoutes = require('./routes/media');

const app = express();
const httpServer = createServer(app);

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGINS?.split(',') || '*',
  credentials: true
}));

// Request parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(compression());

// Logging
app.use(morgan('combined', {
  stream: { write: (message) => logger.info(message.trim()) }
}));

// Health checks
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Rodnya API',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', database: 'connected' });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', database: 'disconnected' });
  }
});

// API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/chats', chatRoutes);
app.use('/api/v1/messages', messageRoutes);
app.use('/api/v1/contacts', contactRoutes);
app.use('/api/v1/calls', callRoutes);
app.use('/api/v1/media', mediaRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message
  });
});

// Startup
const PORT = process.env.PORT || 3000;

const start = async () => {
  try {
    // Connect to Redis
    await createRedisClient();
    logger.info('Redis connected');

    // Run database migrations
    await runMigrations();
    logger.info('Database migrations completed');

    // Initialize WebSocket
    initializeWebSocket(httpServer);
    logger.info('WebSocket initialized');

    // Start server
    httpServer.listen(PORT, () => {
      logger.info(`🚀 Rodnya API running on port ${PORT}`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down...');
  httpServer.close(() => {
    pool.end();
    process.exit(0);
  });
});

start();
