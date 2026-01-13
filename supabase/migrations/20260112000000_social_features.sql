-- Social Features Migration
-- Adds leaderboards, challenges, and friends

-- Challenges table
CREATE TABLE IF NOT EXISTS challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL DEFAULT 'weekly',
    target_minutes INTEGER NOT NULL,
    start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_date TIMESTAMPTZ NOT NULL,
    creator_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    creator_name TEXT,
    is_public BOOLEAN DEFAULT true,
    invite_code TEXT UNIQUE,
    xp_reward INTEGER DEFAULT 100,
    participant_ids TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Challenge participants
CREATE TABLE IF NOT EXISTS challenge_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT,
    avatar_url TEXT,
    minutes_completed INTEGER DEFAULT 0,
    has_completed BOOLEAN DEFAULT false,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(challenge_id, user_id)
);

-- Friends table
CREATE TABLE IF NOT EXISTS friends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    friend_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, friend_user_id)
);

-- Add username and avatar to user_stats if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_stats' AND column_name = 'username') THEN
        ALTER TABLE user_stats ADD COLUMN username TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_stats' AND column_name = 'avatar_url') THEN
        ALTER TABLE user_stats ADD COLUMN avatar_url TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_stats' AND column_name = 'total_focus_minutes') THEN
        ALTER TABLE user_stats ADD COLUMN total_focus_minutes INTEGER DEFAULT 0;
    END IF;
END $$;

-- Function to increment challenge progress
CREATE OR REPLACE FUNCTION increment_challenge_progress(
    p_challenge_id UUID,
    p_user_id UUID,
    p_minutes INTEGER
) RETURNS VOID AS $$
DECLARE
    v_target INTEGER;
    v_current INTEGER;
BEGIN
    -- Get challenge target
    SELECT target_minutes INTO v_target FROM challenges WHERE id = p_challenge_id;
    
    -- Update participant progress
    UPDATE challenge_participants
    SET minutes_completed = minutes_completed + p_minutes,
        has_completed = (minutes_completed + p_minutes) >= v_target
    WHERE challenge_id = p_challenge_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_challenges_public ON challenges(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_challenges_end_date ON challenges(end_date);
CREATE INDEX IF NOT EXISTS idx_challenge_participants_user ON challenge_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_user ON friends(user_id);
CREATE INDEX IF NOT EXISTS idx_user_stats_total_minutes ON user_stats(total_focus_minutes DESC);

-- RLS Policies
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;

-- Challenges: Anyone can view public challenges
CREATE POLICY "Public challenges visible to all" ON challenges
    FOR SELECT USING (is_public = true OR creator_id = auth.uid() OR auth.uid()::text = ANY(participant_ids));

-- Challenges: Authenticated users can create
CREATE POLICY "Authenticated users can create challenges" ON challenges
    FOR INSERT WITH CHECK (auth.uid() = creator_id);

-- Challenges: Creator can update
CREATE POLICY "Creator can update challenge" ON challenges
    FOR UPDATE USING (auth.uid() = creator_id);

-- Challenge participants: Participants can view
CREATE POLICY "Participants can view" ON challenge_participants
    FOR SELECT USING (true);

-- Challenge participants: Users can join
CREATE POLICY "Users can join challenges" ON challenge_participants
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Challenge participants: Users can update own progress
CREATE POLICY "Users can update own progress" ON challenge_participants
    FOR UPDATE USING (auth.uid() = user_id);

-- Friends: Users can view own friends
CREATE POLICY "Users can view own friends" ON friends
    FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_user_id);

-- Friends: Users can add friends
CREATE POLICY "Users can add friends" ON friends
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Friends: Users can manage own friendships
CREATE POLICY "Users can manage own friendships" ON friends
    FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = friend_user_id);

CREATE POLICY "Users can remove friendships" ON friends
    FOR DELETE USING (auth.uid() = user_id OR auth.uid() = friend_user_id);
