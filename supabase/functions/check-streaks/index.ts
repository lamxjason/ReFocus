// ReFocus Streak Protection Edge Function
// Runs daily via pg_cron to protect user streaks
//
// Features:
// - Identifies users at risk of losing their streak
// - Auto-uses streak freeze if available
// - Sends push notification warnings (when configured)
//
// Schedule: Run daily at 11 PM in each user's timezone (or UTC default)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface UserAtRisk {
  user_id: string;
  current_streak: number;
  streak_freezes_available: number;
  last_session_date: string;
}

interface StreakProtectionResult {
  user_id: string;
  action: "freeze_used" | "notification_sent" | "streak_lost" | "no_action";
  streak_preserved: number | null;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Create Supabase client with service role for admin access
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get yesterday's date (users who haven't had a session yesterday are at risk)
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().split("T")[0];

    // Find users at risk of losing their streak
    // Users whose last_session_date is before yesterday with streak > 0
    const { data: usersAtRisk, error: fetchError } = await supabase
      .from("user_stats")
      .select("user_id, current_streak, streak_freezes_available, last_session_date")
      .gt("current_streak", 0)
      .lt("last_session_date", yesterdayStr);

    if (fetchError) {
      throw new Error(`Failed to fetch at-risk users: ${fetchError.message}`);
    }

    const results: StreakProtectionResult[] = [];

    for (const user of (usersAtRisk as UserAtRisk[]) || []) {
      const result = await processAtRiskUser(supabase, user);
      results.push(result);
    }

    // Also reset daily streak freeze flag
    await resetDailyStreakFreezeFlags(supabase);

    return new Response(
      JSON.stringify({
        success: true,
        processed: results.length,
        results: results,
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Streak protection error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

async function processAtRiskUser(
  supabase: any,
  user: UserAtRisk
): Promise<StreakProtectionResult> {
  const { user_id, current_streak, streak_freezes_available } = user;

  // Check if user has streak freezes available
  if (streak_freezes_available > 0) {
    // Auto-use streak freeze
    const { error: freezeError } = await supabase.rpc("use_streak_freeze", {
      p_user_id: user_id,
    });

    if (!freezeError) {
      console.log(`Streak freeze used for user ${user_id}, preserving ${current_streak} day streak`);

      // Log to bonus_rewards table
      await supabase.from("bonus_rewards").insert({
        user_id: user_id,
        reward_type: "streak_freeze_auto_used",
        reward_value: current_streak,
        reward_metadata: {
          auto_used: true,
          streak_preserved: current_streak,
        },
      });

      return {
        user_id,
        action: "freeze_used",
        streak_preserved: current_streak,
      };
    }
  }

  // No freeze available - streak will be lost
  // In future: Send push notification warning
  console.log(`User ${user_id} will lose ${current_streak} day streak (no freezes available)`);

  return {
    user_id,
    action: "streak_lost",
    streak_preserved: null,
  };
}

async function resetDailyStreakFreezeFlags(supabase: any): Promise<void> {
  // Reset the streak_freeze_used_today flag for all users
  const { error } = await supabase
    .from("user_stats")
    .update({ streak_freeze_used_today: false })
    .eq("streak_freeze_used_today", true);

  if (error) {
    console.error("Failed to reset daily streak freeze flags:", error);
  }
}
