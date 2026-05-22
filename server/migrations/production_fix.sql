-- ================================================================
-- PRODUCTION MIGRATION SCRIPT
-- Run this in your Supabase SQL Editor to fix all missing columns
-- that are defined in the Sequelize models but missing from the DB.
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- 1. conversations → add disappearing_duration column
-- ────────────────────────────────────────────────────────────────
ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS disappearing_duration INTEGER DEFAULT NULL;

-- ────────────────────────────────────────────────────────────────
-- 2. messages → add is_edited, edited_at, expires_at, reactions
-- ────────────────────────────────────────────────────────────────
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS is_edited    BOOLEAN   NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS edited_at    TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS expires_at   TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS reactions    JSONB     NOT NULL DEFAULT '{}';

-- ────────────────────────────────────────────────────────────────
-- 3. Create saved_reels table (new – mirrors saved_posts)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS saved_reels (
  id           UUID                     PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID                     NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
  reel_id      UUID                     NOT NULL REFERENCES reels(id)  ON DELETE CASCADE,
  created_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

  CONSTRAINT unique_user_reel_save UNIQUE (user_id, reel_id)
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_saved_reels_user_id  ON saved_reels (user_id);
CREATE INDEX IF NOT EXISTS idx_saved_reels_reel_id  ON saved_reels (reel_id);

-- ────────────────────────────────────────────────────────────────
-- 4. Verify – quick sanity check (check counts, not rows)
-- ────────────────────────────────────────────────────────────────
SELECT
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_name = 'conversations' AND column_name = 'disappearing_duration') AS conv_disappearing_duration,
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_name = 'messages'      AND column_name = 'is_edited')             AS msg_is_edited,
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_name = 'messages'      AND column_name = 'edited_at')             AS msg_edited_at,
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_name = 'messages'      AND column_name = 'expires_at')            AS msg_expires_at,
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_name = 'messages'      AND column_name = 'reactions')             AS msg_reactions,
  (SELECT COUNT(*) FROM information_schema.tables
   WHERE table_name = 'saved_reels')                                             AS saved_reels_table;
-- All values should be 1 if migration succeeded.
