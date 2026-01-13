-- ReFocus Supabase Database Setup
-- Run this in the Supabase SQL Editor: https://supabase.com/dashboard/project/hmqdcnxsbtfivyrdiolm/sql

-- ============================================
-- 1. CREATE TABLES
-- ============================================

-- Timer state (one row per user, synced across devices)
CREATE TABLE IF NOT EXISTS timer_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT FALSE,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    planned_duration_seconds INTEGER,
    last_modified_by TEXT,
    last_modified_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Blocked websites (synced across devices)
CREATE TABLE IF NOT EXISTS blocked_websites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    domain TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, domain)
);

-- Focus sessions history
CREATE TABLE IF NOT EXISTS focus_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    planned_duration_seconds INTEGER NOT NULL,
    actual_duration_seconds INTEGER,
    was_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Devices (for tracking which devices are registered)
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT,
    platform TEXT NOT NULL,
    os_version TEXT,
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- ============================================
-- 2. CREATE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_timer_states_user_id ON timer_states(user_id);
CREATE INDEX IF NOT EXISTS idx_blocked_websites_user_id ON blocked_websites(user_id);
CREATE INDEX IF NOT EXISTS idx_focus_sessions_user_id ON focus_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_focus_sessions_start_time ON focus_sessions(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);

-- ============================================
-- 3. ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE timer_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_websites ENABLE ROW LEVEL SECURITY;
ALTER TABLE focus_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. CREATE RLS POLICIES
-- ============================================

-- Timer states policies
CREATE POLICY "Users can view own timer state"
    ON timer_states FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own timer state"
    ON timer_states FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own timer state"
    ON timer_states FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own timer state"
    ON timer_states FOR DELETE
    USING (auth.uid() = user_id);

-- Blocked websites policies
CREATE POLICY "Users can view own blocked websites"
    ON blocked_websites FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own blocked websites"
    ON blocked_websites FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own blocked websites"
    ON blocked_websites FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own blocked websites"
    ON blocked_websites FOR DELETE
    USING (auth.uid() = user_id);

-- Focus sessions policies
CREATE POLICY "Users can view own focus sessions"
    ON focus_sessions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own focus sessions"
    ON focus_sessions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own focus sessions"
    ON focus_sessions FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own focus sessions"
    ON focus_sessions FOR DELETE
    USING (auth.uid() = user_id);

-- Devices policies
CREATE POLICY "Users can view own devices"
    ON devices FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own devices"
    ON devices FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own devices"
    ON devices FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices"
    ON devices FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- 5. ENABLE REALTIME
-- ============================================

-- Enable realtime for timer_states and blocked_websites
ALTER PUBLICATION supabase_realtime ADD TABLE timer_states;
ALTER PUBLICATION supabase_realtime ADD TABLE blocked_websites;

-- ============================================
-- 6. CREATE HELPER FUNCTIONS
-- ============================================

-- Function to get or create timer state for user
CREATE OR REPLACE FUNCTION get_or_create_timer_state()
RETURNS timer_states
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result timer_states;
BEGIN
    -- Try to get existing timer state
    SELECT * INTO result FROM timer_states WHERE user_id = auth.uid();

    -- If not found, create new one
    IF NOT FOUND THEN
        INSERT INTO timer_states (user_id, is_active)
        VALUES (auth.uid(), false)
        RETURNING * INTO result;
    END IF;

    RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_or_create_timer_state() TO authenticated;
