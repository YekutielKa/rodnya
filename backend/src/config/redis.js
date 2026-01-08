const { createClient } = require('redis');
const logger = require('../utils/logger');

let client = null;
let subscriber = null;

const createRedisClient = async () => {
  if (client) return client;

  client = createClient({
    url: process.env.REDIS_URL,
    socket: {
      reconnectStrategy: (retries) => {
        if (retries > 10) {
          logger.error('Redis: Max reconnection attempts reached');
          return new Error('Max reconnection attempts reached');
        }
        return Math.min(retries * 100, 3000);
      }
    }
  });

  client.on('error', (err) => logger.error('Redis Client Error:', err));
  client.on('connect', () => logger.info('Redis connected'));
  client.on('reconnecting', () => logger.warn('Redis reconnecting...'));

  await client.connect();
  return client;
};

const getSubscriber = async () => {
  if (subscriber) return subscriber;
  subscriber = client.duplicate();
  await subscriber.connect();
  return subscriber;
};

const cache = {
  async get(key) {
    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  },
  async set(key, value, ttlSeconds = 3600) {
    await client.setEx(key, ttlSeconds, JSON.stringify(value));
  },
  async del(key) {
    await client.del(key);
  },
  async delPattern(pattern) {
    const keys = await client.keys(pattern);
    if (keys.length > 0) {
      await client.del(keys);
    }
  }
};

const pubsub = {
  async publish(channel, message) {
    await client.publish(channel, JSON.stringify(message));
  },
  async subscribe(channel, callback) {
    const sub = await getSubscriber();
    await sub.subscribe(channel, (message) => {
      callback(JSON.parse(message));
    });
  }
};

module.exports = { createRedisClient, getClient: () => client, cache, pubsub };
