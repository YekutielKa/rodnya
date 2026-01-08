const { pool } = require('../config/database');
const logger = require('../utils/logger');

const migrations = [
  {
    name: '001_initial_schema',
    up: `
      -- Extensions
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
      CREATE EXTENSION IF NOT EXISTS "pgcrypto";

      -- Users table
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        phone VARCHAR(20) UNIQUE NOT NULL,
        phone_hash VARCHAR(64) NOT NULL,
        name VARCHAR(100) NOT NULL,
        avatar_url TEXT,
        status VARCHAR(200) DEFAULT '',
        last_seen TIMESTAMPTZ DEFAULT NOW(),
        is_online BOOLEAN DEFAULT FALSE,
        privacy_settings JSONB DEFAULT '{"last_seen": "everyone", "avatar": "everyone", "status": "everyone"}',
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
      CREATE INDEX IF NOT EXISTS idx_users_phone_hash ON users(phone_hash);

      -- User devices
      CREATE TABLE IF NOT EXISTS user_devices (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        device_id VARCHAR(255) NOT NULL,
        device_type VARCHAR(20) NOT NULL CHECK (device_type IN ('ios', 'android', 'web')),
        device_name VARCHAR(100),
        push_token TEXT,
        app_version VARCHAR(20),
        is_active BOOLEAN DEFAULT TRUE,
        last_active TIMESTAMPTZ DEFAULT NOW(),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user_id, device_id)
      );

      CREATE INDEX IF NOT EXISTS idx_user_devices_user ON user_devices(user_id);
      CREATE INDEX IF NOT EXISTS idx_user_devices_push ON user_devices(push_token) WHERE push_token IS NOT NULL;

      -- Refresh tokens
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        device_id UUID REFERENCES user_devices(id) ON DELETE CASCADE,
        token_hash VARCHAR(64) NOT NULL UNIQUE,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        revoked_at TIMESTAMPTZ
      );

      CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
      CREATE INDEX IF NOT EXISTS idx_refresh_tokens_hash ON refresh_tokens(token_hash);

      -- OTP codes
      CREATE TABLE IF NOT EXISTS otp_codes (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        phone VARCHAR(20) NOT NULL,
        code VARCHAR(6) NOT NULL,
        attempts INTEGER DEFAULT 0,
        expires_at TIMESTAMPTZ NOT NULL,
        verified_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_otp_codes_phone ON otp_codes(phone);

      -- Contacts
      CREATE TABLE IF NOT EXISTS contacts (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        contact_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        nickname VARCHAR(100),
        is_favorite BOOLEAN DEFAULT FALSE,
        is_blocked BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user_id, contact_user_id)
      );

      CREATE INDEX IF NOT EXISTS idx_contacts_user ON contacts(user_id);
      CREATE INDEX IF NOT EXISTS idx_contacts_blocked ON contacts(user_id, is_blocked) WHERE is_blocked = TRUE;

      -- Chats
      CREATE TABLE IF NOT EXISTS chats (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        type VARCHAR(20) NOT NULL DEFAULT 'direct' CHECK (type IN ('direct', 'group')),
        name VARCHAR(100),
        description TEXT,
        avatar_url TEXT,
        created_by UUID REFERENCES users(id),
        last_message_id UUID,
        last_message_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_chats_updated ON chats(updated_at DESC);

      -- Chat members
      CREATE TABLE IF NOT EXISTS chat_members (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'member')),
        joined_at TIMESTAMPTZ DEFAULT NOW(),
        last_read_at TIMESTAMPTZ,
        last_read_message_id UUID,
        unread_count INTEGER DEFAULT 0,
        is_muted BOOLEAN DEFAULT FALSE,
        muted_until TIMESTAMPTZ,
        is_pinned BOOLEAN DEFAULT FALSE,
        is_archived BOOLEAN DEFAULT FALSE,
        UNIQUE(chat_id, user_id)
      );

      CREATE INDEX IF NOT EXISTS idx_chat_members_chat ON chat_members(chat_id);
      CREATE INDEX IF NOT EXISTS idx_chat_members_user ON chat_members(user_id);
      CREATE INDEX IF NOT EXISTS idx_chat_members_user_active ON chat_members(user_id, is_archived) WHERE is_archived = FALSE;

      -- Messages
      CREATE TABLE IF NOT EXISTS messages (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
        sender_id UUID NOT NULL REFERENCES users(id),
        type VARCHAR(20) NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'video', 'voice', 'file', 'location', 'contact', 'sticker', 'system')),
        content TEXT,
        metadata JSONB DEFAULT '{}',
        reply_to_id UUID REFERENCES messages(id),
        forward_from_id UUID REFERENCES messages(id),
        is_edited BOOLEAN DEFAULT FALSE,
        edited_at TIMESTAMPTZ,
        is_deleted BOOLEAN DEFAULT FALSE,
        deleted_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
      CREATE INDEX IF NOT EXISTS idx_messages_chat_created ON messages(chat_id, created_at);

      -- Message status (delivery receipts)
      CREATE TABLE IF NOT EXISTS message_status (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status VARCHAR(20) NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
        status_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(message_id, user_id)
      );

      CREATE INDEX IF NOT EXISTS idx_message_status_message ON message_status(message_id);

      -- Calls
      CREATE TABLE IF NOT EXISTS calls (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        chat_id UUID REFERENCES chats(id),
        caller_id UUID NOT NULL REFERENCES users(id),
        type VARCHAR(20) NOT NULL CHECK (type IN ('audio', 'video')),
        status VARCHAR(20) NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'ringing', 'accepted', 'rejected', 'missed', 'ended', 'busy', 'failed')),
        started_at TIMESTAMPTZ,
        ended_at TIMESTAMPTZ,
        duration_seconds INTEGER,
        end_reason VARCHAR(50),
        created_at TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_calls_chat ON calls(chat_id);
      CREATE INDEX IF NOT EXISTS idx_calls_caller ON calls(caller_id);
      CREATE INDEX IF NOT EXISTS idx_calls_created ON calls(created_at DESC);

      -- Call participants
      CREATE TABLE IF NOT EXISTS call_participants (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        call_id UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id),
        status VARCHAR(20) NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'ringing', 'accepted', 'rejected', 'left', 'failed')),
        joined_at TIMESTAMPTZ,
        left_at TIMESTAMPTZ,
        UNIQUE(call_id, user_id)
      );

      CREATE INDEX IF NOT EXISTS idx_call_participants_call ON call_participants(call_id);

      -- Media files
      CREATE TABLE IF NOT EXISTS media_files (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        uploader_id UUID NOT NULL REFERENCES users(id),
        message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
        type VARCHAR(20) NOT NULL CHECK (type IN ('image', 'video', 'voice', 'file', 'avatar')),
        original_name VARCHAR(255),
        mime_type VARCHAR(100),
        size_bytes BIGINT,
        storage_key VARCHAR(500) NOT NULL,
        thumbnail_key VARCHAR(500),
        width INTEGER,
        height INTEGER,
        duration_seconds INTEGER,
        metadata JSONB DEFAULT '{}',
        created_at TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_media_files_uploader ON media_files(uploader_id);
      CREATE INDEX IF NOT EXISTS idx_media_files_message ON media_files(message_id);

      -- Invites (closed system)
      CREATE TABLE IF NOT EXISTS invites (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        code VARCHAR(20) UNIQUE NOT NULL,
        created_by UUID NOT NULL REFERENCES users(id),
        used_by UUID REFERENCES users(id),
        max_uses INTEGER DEFAULT 1,
        use_count INTEGER DEFAULT 0,
        expires_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        used_at TIMESTAMPTZ
      );

      CREATE INDEX IF NOT EXISTS idx_invites_code ON invites(code);
      CREATE INDEX IF NOT EXISTS idx_invites_creator ON invites(created_by);

      -- Push notification queue
      CREATE TABLE IF NOT EXISTS push_queue (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        device_id UUID REFERENCES user_devices(id) ON DELETE CASCADE,
        payload JSONB NOT NULL,
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
        attempts INTEGER DEFAULT 0,
        last_attempt_at TIMESTAMPTZ,
        error_message TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_push_queue_pending ON push_queue(status, created_at) WHERE status = 'pending';

      -- Migrations tracking
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL UNIQUE,
        executed_at TIMESTAMPTZ DEFAULT NOW()
      );
    `
  },
  {
    name: '002_functions_and_triggers',
    up: `
      -- Function to update updated_at timestamp
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
      END;
      $$ language 'plpgsql';

      -- Trigger for users
      DROP TRIGGER IF EXISTS update_users_updated_at ON users;
      CREATE TRIGGER update_users_updated_at
        BEFORE UPDATE ON users
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();

      -- Trigger for chats
      DROP TRIGGER IF EXISTS update_chats_updated_at ON chats;
      CREATE TRIGGER update_chats_updated_at
        BEFORE UPDATE ON chats
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();

      -- Function to update chat's last message
      CREATE OR REPLACE FUNCTION update_chat_last_message()
      RETURNS TRIGGER AS $$
      BEGIN
        UPDATE chats 
        SET last_message_id = NEW.id, 
            last_message_at = NEW.created_at,
            updated_at = NOW()
        WHERE id = NEW.chat_id;
        RETURN NEW;
      END;
      $$ language 'plpgsql';

      -- Trigger for new messages
      DROP TRIGGER IF EXISTS update_chat_on_new_message ON messages;
      CREATE TRIGGER update_chat_on_new_message
        AFTER INSERT ON messages
        FOR EACH ROW
        EXECUTE FUNCTION update_chat_last_message();

      -- Function to increment unread count
      CREATE OR REPLACE FUNCTION increment_unread_count()
      RETURNS TRIGGER AS $$
      BEGIN
        UPDATE chat_members 
        SET unread_count = unread_count + 1
        WHERE chat_id = NEW.chat_id 
          AND user_id != NEW.sender_id;
        RETURN NEW;
      END;
      $$ language 'plpgsql';

      -- Trigger for unread count
      DROP TRIGGER IF EXISTS increment_unread_on_message ON messages;
      CREATE TRIGGER increment_unread_on_message
        AFTER INSERT ON messages
        FOR EACH ROW
        EXECUTE FUNCTION increment_unread_count();
    `
  }
];

const runMigrations = async () => {
  const client = await pool.connect();
  
  try {
    // Ensure migrations table exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL UNIQUE,
        executed_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);

    // Get executed migrations
    const { rows: executed } = await client.query('SELECT name FROM migrations');
    const executedNames = executed.map(r => r.name);

    // Run pending migrations
    for (const migration of migrations) {
      if (!executedNames.includes(migration.name)) {
        logger.info(`Running migration: ${migration.name}`);
        
        await client.query('BEGIN');
        try {
          await client.query(migration.up);
          await client.query('INSERT INTO migrations (name) VALUES ($1)', [migration.name]);
          await client.query('COMMIT');
          logger.info(`Migration completed: ${migration.name}`);
        } catch (error) {
          await client.query('ROLLBACK');
          throw error;
        }
      }
    }

    logger.info('All migrations completed');
  } finally {
    client.release();
  }
};

module.exports = { runMigrations };
