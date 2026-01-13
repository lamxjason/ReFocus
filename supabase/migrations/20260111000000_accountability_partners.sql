-- ReFocus Accountability Partners Feature
-- Enables users to require partner approval before unlocking blocked apps

-- ============================================
-- ACCOUNTABILITY PARTNERSHIPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS accountability_partnerships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    partner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'revoked')),
    invite_code TEXT UNIQUE,
    invite_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    UNIQUE(user_id, partner_user_id),
    CHECK (user_id != partner_user_id)
);

-- ============================================
-- ACCOUNTABILITY CONFIG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS accountability_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    is_enabled BOOLEAN NOT NULL DEFAULT false,
    required_approvals INTEGER NOT NULL DEFAULT 1 CHECK (required_approvals >= 1),
    request_timeout_minutes INTEGER NOT NULL DEFAULT 10,
    cooldown_minutes INTEGER NOT NULL DEFAULT 5,
    allow_proximity_unlock BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- UNLOCK REQUESTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS unlock_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'expired', 'cancelled')),
    required_approvals INTEGER NOT NULL,
    received_approvals INTEGER NOT NULL DEFAULT 0,
    request_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    resolved_at TIMESTAMPTZ,
    requesting_device_id TEXT NOT NULL
);

-- ============================================
-- UNLOCK APPROVALS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS unlock_approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES unlock_requests(id) ON DELETE CASCADE,
    partner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    approval_method TEXT NOT NULL CHECK (approval_method IN ('notification', 'proximity')),
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approving_device_id TEXT,
    UNIQUE(request_id, partner_user_id)
);

-- ============================================
-- DEVICE PUSH TOKENS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS device_push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    push_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'macos')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_partnerships_user_id ON accountability_partnerships(user_id);
CREATE INDEX IF NOT EXISTS idx_partnerships_partner_id ON accountability_partnerships(partner_user_id);
CREATE INDEX IF NOT EXISTS idx_partnerships_invite_code ON accountability_partnerships(invite_code) WHERE invite_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_unlock_requests_user_status ON unlock_requests(user_id, status);
CREATE INDEX IF NOT EXISTS idx_unlock_approvals_request ON unlock_approvals(request_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON device_push_tokens(user_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE accountability_partnerships ENABLE ROW LEVEL SECURITY;
ALTER TABLE accountability_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE unlock_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE unlock_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_push_tokens ENABLE ROW LEVEL SECURITY;

-- Partnerships: Users can see their own partnerships
CREATE POLICY "Users can view own partnerships" ON accountability_partnerships
    FOR SELECT USING (auth.uid() = user_id OR auth.uid() = partner_user_id);

CREATE POLICY "Users can create partnerships" ON accountability_partnerships
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own partnerships" ON accountability_partnerships
    FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = partner_user_id);

CREATE POLICY "Users can delete own partnerships" ON accountability_partnerships
    FOR DELETE USING (auth.uid() = user_id);

-- Config: Users only access their own
CREATE POLICY "Users can manage own config" ON accountability_config
    FOR ALL USING (auth.uid() = user_id);

-- Unlock Requests
CREATE POLICY "Users can view own requests" ON unlock_requests
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Partners can view requests to approve" ON unlock_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM accountability_partnerships
            WHERE partner_user_id = auth.uid()
            AND user_id = unlock_requests.user_id
            AND status = 'active'
        )
    );

CREATE POLICY "Users can create own requests" ON unlock_requests
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own requests" ON unlock_requests
    FOR UPDATE USING (auth.uid() = user_id);

-- Approvals
CREATE POLICY "Users can view approvals for their requests" ON unlock_approvals
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM unlock_requests WHERE id = request_id AND user_id = auth.uid())
    );

CREATE POLICY "Partners can view their approvals" ON unlock_approvals
    FOR SELECT USING (partner_user_id = auth.uid());

CREATE POLICY "Partners can approve requests" ON unlock_approvals
    FOR INSERT WITH CHECK (
        partner_user_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM accountability_partnerships ap
            JOIN unlock_requests ur ON ur.user_id = ap.user_id
            WHERE ap.partner_user_id = auth.uid()
            AND ap.status = 'active'
            AND ur.id = request_id
            AND ur.status = 'pending'
        )
    );

-- Push Tokens
CREATE POLICY "Users can manage own push tokens" ON device_push_tokens
    FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- ENABLE REALTIME
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE unlock_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE unlock_approvals;
ALTER PUBLICATION supabase_realtime ADD TABLE accountability_partnerships;
ALTER PUBLICATION supabase_realtime ADD TABLE accountability_config;

-- ============================================
-- TRIGGER: Increment approval count and auto-approve
-- ============================================
CREATE OR REPLACE FUNCTION increment_approval_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE unlock_requests
    SET received_approvals = received_approvals + 1,
        status = CASE
            WHEN received_approvals + 1 >= required_approvals THEN 'approved'
            ELSE status
        END,
        resolved_at = CASE
            WHEN received_approvals + 1 >= required_approvals THEN NOW()
            ELSE resolved_at
        END
    WHERE id = NEW.request_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_increment_approval_count
    AFTER INSERT ON unlock_approvals
    FOR EACH ROW
    EXECUTE FUNCTION increment_approval_count();

-- Auto-update timestamps
CREATE TRIGGER update_accountability_config_updated_at
    BEFORE UPDATE ON accountability_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_push_tokens_updated_at
    BEFORE UPDATE ON device_push_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
