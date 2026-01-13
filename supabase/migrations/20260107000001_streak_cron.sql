-- Schedule daily streak protection check
-- Runs at 11 PM UTC to auto-use streak freezes for at-risk users

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule the streak check Edge Function to run daily at 11 PM UTC
SELECT cron.schedule(
  'check-streaks-daily',
  '0 23 * * *',
  $$
  SELECT net.http_post(
    url := 'https://hmqdcnxsbtfivyrdiolm.supabase.co/functions/v1/check-streaks',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  )
  $$
);

-- Note: For authenticated requests, you'll need to add the service role key
-- in the Supabase Dashboard under Edge Functions > check-streaks > Settings
