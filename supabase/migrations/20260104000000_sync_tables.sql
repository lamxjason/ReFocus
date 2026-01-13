-- ReFocus Supabase Sync Tables
-- Run this migration to enable full cross-device sync

-- ============================================
-- FOCUS MODES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS focus_modes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT NOT NULL DEFAULT 'timer',
    color TEXT NOT NULL DEFAULT '8B5CF6',
    duration_seconds INTEGER NOT NULL DEFAULT 1500,
    is_strict_mode BOOLEAN NOT NULL DEFAULT false,
    website_domains TEXT[] NOT NULL DEFAULT '{}',
    theme_gradient_primary TEXT,
    theme_gradient_secondary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    device_id TEXT, -- Track which device last modified
    UNIQUE(user_id, name) -- Prevent duplicate mode names per user
);

-- Enable RLS
ALTER TABLE focus_modes ENABLE ROW LEVEL SECURITY;

-- Users can only access their own modes
CREATE POLICY "Users can view own focus modes" ON focus_modes
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own focus modes" ON focus_modes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own focus modes" ON focus_modes
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own focus modes" ON focus_modes
    FOR DELETE USING (auth.uid() = user_id);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE focus_modes;

-- ============================================
-- FOCUS SCHEDULES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS focus_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_hour INTEGER NOT NULL CHECK (start_hour >= 0 AND start_hour < 24),
    start_minute INTEGER NOT NULL CHECK (start_minute >= 0 AND start_minute < 60),
    end_hour INTEGER NOT NULL CHECK (end_hour >= 0 AND end_hour < 24),
    end_minute INTEGER NOT NULL CHECK (end_minute >= 0 AND end_minute < 60),
    days INTEGER[] NOT NULL DEFAULT '{1,2,3,4,5,6,7}', -- 1=Sunday, 7=Saturday
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    is_strict_mode BOOLEAN NOT NULL DEFAULT false,
    focus_mode_id UUID REFERENCES focus_modes(id) ON DELETE SET NULL,
    website_domains TEXT[] NOT NULL DEFAULT '{}',
    theme_gradient_primary TEXT,
    theme_gradient_secondary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    device_id TEXT,
    UNIQUE(user_id, name)
);

-- Enable RLS
ALTER TABLE focus_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own schedules" ON focus_schedules
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own schedules" ON focus_schedules
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own schedules" ON focus_schedules
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own schedules" ON focus_schedules
    FOR DELETE USING (auth.uid() = user_id);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE focus_schedules;

-- ============================================
-- USER SETTINGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    is_strict_mode_enabled BOOLEAN NOT NULL DEFAULT false,
    minimum_commitment_minutes INTEGER NOT NULL DEFAULT 5,
    exits_used_this_month INTEGER NOT NULL DEFAULT 0,
    month_start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    weekly_goal_hours NUMERIC(4,1) NOT NULL DEFAULT 10.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own settings" ON user_settings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings" ON user_settings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own settings" ON user_settings
    FOR UPDATE USING (auth.uid() = user_id);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE user_settings;

-- ============================================
-- USER STATS TABLE (Derived from sessions)
-- ============================================
CREATE TABLE IF NOT EXISTS user_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    total_xp INTEGER NOT NULL DEFAULT 0,
    current_level INTEGER NOT NULL DEFAULT 1,
    current_streak INTEGER NOT NULL DEFAULT 0,
    longest_streak INTEGER NOT NULL DEFAULT 0,
    last_session_date DATE,
    total_focus_seconds BIGINT NOT NULL DEFAULT 0,
    total_sessions INTEGER NOT NULL DEFAULT 0,
    completed_sessions INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own stats" ON user_stats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own stats" ON user_stats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own stats" ON user_stats
    FOR UPDATE USING (auth.uid() = user_id);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE user_stats;

-- ============================================
-- FUNCTION: Update user stats after session
-- ============================================
CREATE OR REPLACE FUNCTION update_user_stats_after_session()
RETURNS TRIGGER AS $$
DECLARE
    session_xp INTEGER;
    new_streak INTEGER;
    last_date DATE;
BEGIN
    -- Calculate XP (10 per minute + 50% bonus if completed)
    session_xp := (NEW.actual_duration_seconds / 60) * 10;
    IF NEW.was_completed THEN
        session_xp := session_xp + (session_xp / 2);
    END IF;

    -- Get or create user stats
    INSERT INTO user_stats (user_id, total_xp, current_level, current_streak, longest_streak, last_session_date, total_focus_seconds, total_sessions, completed_sessions)
    VALUES (NEW.user_id, 0, 1, 0, 0, NULL, 0, 0, 0)
    ON CONFLICT (user_id) DO NOTHING;

    -- Get current last session date
    SELECT last_session_date INTO last_date FROM user_stats WHERE user_id = NEW.user_id;

    -- Calculate streak
    IF last_date IS NULL OR last_date < CURRENT_DATE - INTERVAL '1 day' THEN
        new_streak := 1;
    ELSIF last_date = CURRENT_DATE - INTERVAL '1 day' THEN
        SELECT current_streak + 1 INTO new_streak FROM user_stats WHERE user_id = NEW.user_id;
    ELSIF last_date = CURRENT_DATE THEN
        SELECT current_streak INTO new_streak FROM user_stats WHERE user_id = NEW.user_id;
    ELSE
        new_streak := 1;
    END IF;

    -- Update stats
    UPDATE user_stats SET
        total_xp = total_xp + session_xp,
        current_level = 1 + (total_xp + session_xp) / 1000,
        current_streak = new_streak,
        longest_streak = GREATEST(longest_streak, new_streak),
        last_session_date = CURRENT_DATE,
        total_focus_seconds = total_focus_seconds + NEW.actual_duration_seconds,
        total_sessions = total_sessions + 1,
        completed_sessions = completed_sessions + CASE WHEN NEW.was_completed THEN 1 ELSE 0 END,
        updated_at = NOW()
    WHERE user_id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update stats when session is inserted
DROP TRIGGER IF EXISTS update_stats_on_session ON focus_sessions;
CREATE TRIGGER update_stats_on_session
    AFTER INSERT ON focus_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_user_stats_after_session();

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX IF NOT EXISTS idx_focus_modes_user_id ON focus_modes(user_id);
CREATE INDEX IF NOT EXISTS idx_focus_schedules_user_id ON focus_schedules(user_id);
CREATE INDEX IF NOT EXISTS idx_user_settings_user_id ON user_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_user_stats_user_id ON user_stats(user_id);

-- ============================================
-- AUTO-UPDATE updated_at TRIGGER
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_focus_modes_updated_at
    BEFORE UPDATE ON focus_modes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_focus_schedules_updated_at
    BEFORE UPDATE ON focus_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_settings_updated_at
    BEFORE UPDATE ON user_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
