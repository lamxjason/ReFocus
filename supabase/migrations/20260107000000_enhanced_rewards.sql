-- ReFocus Enhanced Rewards System
-- Implements streak protection, achievements, and enhanced XP calculation
-- Based on research: Streaks increase commitment by 60%, badges boost completion by 30%

-- ============================================
-- STREAK PROTECTION
-- ============================================

-- Add streak freeze feature to user_stats
ALTER TABLE user_stats ADD COLUMN IF NOT EXISTS streak_freezes_available INTEGER NOT NULL DEFAULT 2;
ALTER TABLE user_stats ADD COLUMN IF NOT EXISTS streak_freeze_used_today BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE user_stats ADD COLUMN IF NOT EXISTS streak_freeze_last_used DATE;

-- Daily reset function for streak freezes
CREATE OR REPLACE FUNCTION reset_daily_streak_freeze()
RETURNS void AS $$
BEGIN
    UPDATE user_stats
    SET streak_freeze_used_today = false
    WHERE streak_freeze_used_today = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ACHIEVEMENTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS achievements_earned (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_type TEXT NOT NULL,
    achievement_name TEXT NOT NULL,
    achievement_description TEXT,
    xp_reward INTEGER NOT NULL DEFAULT 0,
    earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(user_id, achievement_type)
);

-- Enable RLS
ALTER TABLE achievements_earned ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own achievements" ON achievements_earned
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own achievements" ON achievements_earned
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE achievements_earned;

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_achievements_user_id ON achievements_earned(user_id);
CREATE INDEX IF NOT EXISTS idx_achievements_type ON achievements_earned(achievement_type);

-- ============================================
-- ENHANCED XP CALCULATION
-- ============================================

-- XP calculation function with multipliers based on research
-- Base: 10 XP per minute
-- Completion bonus: 1.5x
-- 7-day streak bonus: 1.25x
-- 30-day streak bonus: 1.5x
-- Hard mode bonus: 2.0x
CREATE OR REPLACE FUNCTION calculate_session_xp(
    p_duration_seconds INTEGER,
    p_was_completed BOOLEAN,
    p_current_streak INTEGER,
    p_is_hard_mode BOOLEAN DEFAULT false
) RETURNS INTEGER AS $$
DECLARE
    base_xp INTEGER;
    multiplier NUMERIC := 1.0;
BEGIN
    -- Base XP: 10 per minute
    base_xp := (p_duration_seconds / 60) * 10;

    -- Completion bonus (50%)
    IF p_was_completed THEN
        multiplier := multiplier * 1.5;
    END IF;

    -- Streak bonuses (loss aversion psychology - users feel losses 2x more)
    IF p_current_streak >= 30 THEN
        multiplier := multiplier * 1.5;  -- 30-day streak: 50% bonus
    ELSIF p_current_streak >= 7 THEN
        multiplier := multiplier * 1.25; -- 7-day streak: 25% bonus
    END IF;

    -- Hard mode bonus (double XP for commitment)
    IF p_is_hard_mode THEN
        multiplier := multiplier * 2.0;
    END IF;

    RETURN FLOOR(base_xp * multiplier);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- UPDATED SESSION TRIGGER
-- ============================================

-- Drop existing trigger
DROP TRIGGER IF EXISTS update_stats_on_session ON focus_sessions;

-- Enhanced function to update stats and check achievements
CREATE OR REPLACE FUNCTION update_user_stats_after_session()
RETURNS TRIGGER AS $$
DECLARE
    v_session_xp INTEGER;
    v_new_streak INTEGER;
    v_last_date DATE;
    v_current_streak INTEGER;
    v_is_hard_mode BOOLEAN := false; -- TODO: Add hard_mode column to focus_sessions
    v_total_sessions INTEGER;
    v_completed_sessions INTEGER;
    v_total_focus_seconds BIGINT;
BEGIN
    -- Get current stats
    SELECT current_streak, last_session_date, total_sessions, completed_sessions, total_focus_seconds
    INTO v_current_streak, v_last_date, v_total_sessions, v_completed_sessions, v_total_focus_seconds
    FROM user_stats WHERE user_id = NEW.user_id;

    -- Handle case where user_stats doesn't exist yet
    IF NOT FOUND THEN
        INSERT INTO user_stats (user_id, total_xp, current_level, current_streak, longest_streak, last_session_date, total_focus_seconds, total_sessions, completed_sessions)
        VALUES (NEW.user_id, 0, 1, 0, 0, NULL, 0, 0, 0)
        ON CONFLICT (user_id) DO NOTHING;

        v_current_streak := 0;
        v_last_date := NULL;
        v_total_sessions := 0;
        v_completed_sessions := 0;
        v_total_focus_seconds := 0;
    END IF;

    -- Calculate streak
    IF v_last_date IS NULL OR v_last_date < CURRENT_DATE - INTERVAL '1 day' THEN
        v_new_streak := 1;
    ELSIF v_last_date = CURRENT_DATE - INTERVAL '1 day' THEN
        v_new_streak := v_current_streak + 1;
    ELSIF v_last_date = CURRENT_DATE THEN
        v_new_streak := v_current_streak;
    ELSE
        v_new_streak := 1;
    END IF;

    -- Calculate XP with multipliers
    v_session_xp := calculate_session_xp(
        COALESCE(NEW.actual_duration_seconds, 0),
        NEW.was_completed,
        v_new_streak,
        v_is_hard_mode
    );

    -- Update new totals for achievement checking
    v_total_sessions := v_total_sessions + 1;
    IF NEW.was_completed THEN
        v_completed_sessions := v_completed_sessions + 1;
    END IF;
    v_total_focus_seconds := v_total_focus_seconds + COALESCE(NEW.actual_duration_seconds, 0);

    -- Update stats
    UPDATE user_stats SET
        total_xp = total_xp + v_session_xp,
        current_level = 1 + (total_xp + v_session_xp) / 1000,
        current_streak = v_new_streak,
        longest_streak = GREATEST(longest_streak, v_new_streak),
        last_session_date = CURRENT_DATE,
        total_focus_seconds = v_total_focus_seconds,
        total_sessions = v_total_sessions,
        completed_sessions = v_completed_sessions,
        updated_at = NOW()
    WHERE user_id = NEW.user_id;

    -- Check and award achievements
    PERFORM check_and_award_achievements(
        NEW.user_id,
        v_total_sessions,
        v_completed_sessions,
        v_total_focus_seconds,
        v_new_streak
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
CREATE TRIGGER update_stats_on_session
    AFTER INSERT ON focus_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_user_stats_after_session();

-- ============================================
-- ACHIEVEMENT CHECKING FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION check_and_award_achievements(
    p_user_id UUID,
    p_total_sessions INTEGER,
    p_completed_sessions INTEGER,
    p_total_focus_seconds BIGINT,
    p_current_streak INTEGER
) RETURNS void AS $$
DECLARE
    v_total_hours NUMERIC;
BEGIN
    v_total_hours := p_total_focus_seconds / 3600.0;

    -- First Session Achievement
    IF p_total_sessions = 1 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'first_session', 'First Session', 'Completed your first focus session', 100)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    -- Session Count Achievements
    IF p_completed_sessions >= 10 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'sessions_10', '10 Sessions', 'Completed 10 focus sessions', 300)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    IF p_completed_sessions >= 50 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'sessions_50', '50 Sessions', 'Completed 50 focus sessions', 1000)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    IF p_completed_sessions >= 100 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'sessions_100', 'Century', 'Completed 100 focus sessions', 3000)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    -- Streak Achievements (key for retention - 2.3x more likely to return at 7 days)
    IF p_current_streak >= 3 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'streak_3', '3 Day Streak', 'Focused for 3 consecutive days', 200)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    IF p_current_streak >= 7 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'streak_7', 'Week Warrior', 'Focused for 7 consecutive days', 500)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    IF p_current_streak >= 14 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'streak_14', 'Fortnight Focus', 'Focused for 14 consecutive days', 1000)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    IF p_current_streak >= 30 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'streak_30', 'Monthly Master', 'Focused for 30 consecutive days', 2000)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    IF p_current_streak >= 100 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'streak_100', 'Centurion', 'Focused for 100 consecutive days', 10000)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    -- Time Achievements
    IF v_total_hours >= 1 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'hours_1', 'First Hour', 'Accumulated 1 hour of focus time', 100)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    IF v_total_hours >= 10 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'hours_10', '10 Hours', 'Accumulated 10 hours of focus time', 500)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    IF v_total_hours >= 50 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'hours_50', '50 Hours', 'Accumulated 50 hours of focus time', 1500)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

    IF v_total_hours >= 100 THEN
        INSERT INTO achievements_earned (user_id, achievement_type, achievement_name, achievement_description, xp_reward)
        VALUES (p_user_id, 'hours_100', 'Time Master', 'Accumulated 100 hours of focus time', 3000)
        ON CONFLICT (user_id, achievement_type) DO NOTHING;
    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STREAK PROTECTION FUNCTION
-- ============================================

-- Function to use a streak freeze (called when user would lose streak)
CREATE OR REPLACE FUNCTION use_streak_freeze(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_freezes_available INTEGER;
    v_already_used_today BOOLEAN;
BEGIN
    SELECT streak_freezes_available, streak_freeze_used_today
    INTO v_freezes_available, v_already_used_today
    FROM user_stats
    WHERE user_id = p_user_id;

    -- Check if user has freezes available and hasn't used one today
    IF v_freezes_available > 0 AND NOT v_already_used_today THEN
        UPDATE user_stats
        SET streak_freezes_available = streak_freezes_available - 1,
            streak_freeze_used_today = true,
            streak_freeze_last_used = CURRENT_DATE,
            last_session_date = CURRENT_DATE  -- Extend streak
        WHERE user_id = p_user_id;
        RETURN true;
    END IF;

    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION use_streak_freeze(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_session_xp(INTEGER, BOOLEAN, INTEGER, BOOLEAN) TO authenticated;

-- ============================================
-- MONTHLY STREAK FREEZE REPLENISHMENT
-- ============================================

-- Function to replenish streak freezes monthly (grant 2 freezes per month)
CREATE OR REPLACE FUNCTION replenish_monthly_streak_freezes()
RETURNS void AS $$
BEGIN
    UPDATE user_stats
    SET streak_freezes_available = LEAST(streak_freezes_available + 2, 5) -- Max 5 freezes
    WHERE streak_freezes_available < 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- VARIABLE REWARDS TABLE
-- ============================================

-- Track bonus rewards earned (for variable reward psychology)
CREATE TABLE IF NOT EXISTS bonus_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reward_type TEXT NOT NULL, -- 'xp_bonus', 'streak_freeze', 'theme_unlock', 'badge'
    reward_value INTEGER, -- For XP bonuses
    reward_metadata JSONB, -- For other rewards
    session_id UUID REFERENCES focus_sessions(id),
    earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE bonus_rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own rewards" ON bonus_rewards
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own rewards" ON bonus_rewards
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE bonus_rewards;

-- Index
CREATE INDEX IF NOT EXISTS idx_bonus_rewards_user_id ON bonus_rewards(user_id);

-- ============================================
-- LEADERBOARD VIEW (OPTIONAL)
-- ============================================

-- Weekly leaderboard view (top 100 by XP gained this week)
CREATE OR REPLACE VIEW weekly_leaderboard AS
SELECT
    us.user_id,
    us.total_xp,
    us.current_level,
    us.current_streak,
    COUNT(fs.id) AS sessions_this_week,
    COALESCE(SUM(fs.actual_duration_seconds), 0) AS focus_seconds_this_week
FROM user_stats us
LEFT JOIN focus_sessions fs ON fs.user_id = us.user_id
    AND fs.start_time >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY us.user_id, us.total_xp, us.current_level, us.current_streak
ORDER BY us.total_xp DESC
LIMIT 100;

-- Note: Enable RLS on view access through application layer
