-- Family Plan Migration
-- Adds family groups with up to 5 members and accountability locks

-- Family groups table
CREATE TABLE IF NOT EXISTS family_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_name TEXT NOT NULL,
    invite_code TEXT UNIQUE NOT NULL,
    subscription_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Family members table
CREATE TABLE IF NOT EXISTS family_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_group_id UUID REFERENCES family_groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(family_group_id, user_id),
    UNIQUE(user_id) -- User can only be in one family
);

-- Accountability locks table
CREATE TABLE IF NOT EXISTS accountability_locks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_group_id UUID REFERENCES family_groups(id) ON DELETE CASCADE,
    requester_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    requester_name TEXT NOT NULL,
    target_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    target_user_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    duration_minutes INTEGER NOT NULL DEFAULT 30,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- Family activity feed
CREATE TABLE IF NOT EXISTS family_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_group_id UUID REFERENCES family_groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    activity_type TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function to enforce max 5 members per family
CREATE OR REPLACE FUNCTION check_family_member_limit()
RETURNS TRIGGER AS $$
DECLARE
    member_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO member_count
    FROM family_members
    WHERE family_group_id = NEW.family_group_id;
    
    IF member_count >= 5 THEN
        RAISE EXCEPTION 'Family group cannot have more than 5 members';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_family_member_limit
    BEFORE INSERT ON family_members
    FOR EACH ROW
    EXECUTE FUNCTION check_family_member_limit();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_family_members_user ON family_members(user_id);
CREATE INDEX IF NOT EXISTS idx_family_members_group ON family_members(family_group_id);
CREATE INDEX IF NOT EXISTS idx_family_groups_invite ON family_groups(invite_code);
CREATE INDEX IF NOT EXISTS idx_accountability_locks_target ON accountability_locks(target_user_id, status);
CREATE INDEX IF NOT EXISTS idx_family_activities_group ON family_activities(family_group_id, created_at DESC);

-- RLS Policies
ALTER TABLE family_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE accountability_locks ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_activities ENABLE ROW LEVEL SECURITY;

-- Family groups: Members can view their group
CREATE POLICY "Members can view their family group" ON family_groups
    FOR SELECT USING (
        id IN (SELECT family_group_id FROM family_members WHERE user_id = auth.uid())
        OR owner_id = auth.uid()
    );

-- Family groups: Anyone can view by invite code (for joining)
CREATE POLICY "Anyone can view by invite code" ON family_groups
    FOR SELECT USING (true);

-- Family groups: Owner can create
CREATE POLICY "Users can create family groups" ON family_groups
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- Family groups: Owner can update
CREATE POLICY "Owner can update family group" ON family_groups
    FOR UPDATE USING (auth.uid() = owner_id);

-- Family groups: Owner can delete
CREATE POLICY "Owner can delete family group" ON family_groups
    FOR DELETE USING (auth.uid() = owner_id);

-- Family members: Members can view their group's members
CREATE POLICY "Members can view family members" ON family_members
    FOR SELECT USING (
        family_group_id IN (SELECT family_group_id FROM family_members WHERE user_id = auth.uid())
    );

-- Family members: Users can join families
CREATE POLICY "Users can join families" ON family_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Family members: Users can leave, owners can remove
CREATE POLICY "Users can leave or be removed" ON family_members
    FOR DELETE USING (
        auth.uid() = user_id
        OR family_group_id IN (SELECT id FROM family_groups WHERE owner_id = auth.uid())
    );

-- Accountability locks: Family members can view
CREATE POLICY "Family members can view locks" ON accountability_locks
    FOR SELECT USING (
        family_group_id IN (SELECT family_group_id FROM family_members WHERE user_id = auth.uid())
    );

-- Accountability locks: Family members can create
CREATE POLICY "Family members can create locks" ON accountability_locks
    FOR INSERT WITH CHECK (
        family_group_id IN (SELECT family_group_id FROM family_members WHERE user_id = auth.uid())
        AND auth.uid() = requester_id
    );

-- Accountability locks: Target can update (respond)
CREATE POLICY "Target can respond to locks" ON accountability_locks
    FOR UPDATE USING (auth.uid() = target_user_id);

-- Family activities: Members can view
CREATE POLICY "Members can view activities" ON family_activities
    FOR SELECT USING (
        family_group_id IN (SELECT family_group_id FROM family_members WHERE user_id = auth.uid())
    );

-- Family activities: Members can post
CREATE POLICY "Members can post activities" ON family_activities
    FOR INSERT WITH CHECK (
        family_group_id IN (SELECT family_group_id FROM family_members WHERE user_id = auth.uid())
        AND auth.uid() = user_id
    );

-- Function to expire old locks (can be called by cron or manually)
CREATE OR REPLACE FUNCTION expire_accountability_locks()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE accountability_locks
    SET status = 'completed'
    WHERE status = 'active'
    AND expires_at < NOW();
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Auto-expire pending requests after 24 hours
CREATE OR REPLACE FUNCTION expire_pending_lock_requests()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE accountability_locks
    SET status = 'cancelled'
    WHERE status = 'pending'
    AND created_at < NOW() - INTERVAL '24 hours';
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION expire_accountability_locks() TO authenticated;
GRANT EXECUTE ON FUNCTION expire_pending_lock_requests() TO authenticated;
