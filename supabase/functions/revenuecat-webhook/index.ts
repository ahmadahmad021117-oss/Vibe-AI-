// Supabase Edge Function — revenuecat-webhook
// Receives RevenueCat events, upserts the matching row in `entitlements`.
// Configure in RevenueCat dashboard:
//   - Authorization header: shared secret matching REVENUECAT_WEBHOOK_SECRET
//   - URL: https://<your-project>.supabase.co/functions/v1/revenuecat-webhook
// Deploy with --no-verify-jwt (RevenueCat doesn't send a Supabase JWT):
//   supabase functions deploy revenuecat-webhook --no-verify-jwt

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

interface RCEvent {
  event: {
    type: string;
    app_user_id: string;
    product_id?: string;
    expiration_at_ms?: number | null;
    entitlement_ids?: string[] | null;
    entitlement_id?: string | null;
  };
  api_version: string;
}

const PREMIUM_ENTITLEMENT_ID = Deno.env.get('REVENUECAT_PREMIUM_ID') ?? 'premium';

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('method not allowed', { status: 405 });
  }

  const expectedAuth = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
  if (!expectedAuth) {
    return new Response('webhook not configured', { status: 500 });
  }
  if (req.headers.get('Authorization') !== `Bearer ${expectedAuth}`) {
    return new Response('forbidden', { status: 403 });
  }

  let body: RCEvent;
  try {
    body = await req.json();
  } catch {
    return new Response('bad json', { status: 400 });
  }

  const event = body?.event;
  if (!event?.app_user_id || !event.type) {
    return new Response('missing fields', { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // RC sends many event types; we care about ones that change premium state.
  const isActivating = [
    'INITIAL_PURCHASE',
    'RENEWAL',
    'PRODUCT_CHANGE',
    'NON_RENEWING_PURCHASE',
    'UNCANCELLATION',
  ].includes(event.type);
  const isDeactivating = ['CANCELLATION', 'EXPIRATION'].includes(event.type);
  if (!isActivating && !isDeactivating) {
    return new Response('ignored', { status: 200 });
  }

  // Some events list entitlements explicitly; otherwise infer from the product.
  const grantsPremium = isActivating && (
    event.entitlement_ids?.includes(PREMIUM_ENTITLEMENT_ID) ||
    event.entitlement_id === PREMIUM_ENTITLEMENT_ID ||
    !event.entitlement_ids // older webhooks omit; assume default premium offering
  );

  const tier = grantsPremium ? 'premium' : 'free';
  const expiresAt = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;

  // app_user_id must match the Supabase user id we logged in with from the iOS app.
  // Reject anything that doesn't look like a UUID to avoid collisions with RC anon ids.
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(event.app_user_id)) {
    return new Response('non-uuid app_user_id ignored', { status: 200 });
  }

  const { error } = await supabase.from('entitlements').upsert({
    user_id: event.app_user_id,
    tier,
    expires_at: expiresAt,
    product_id: event.product_id ?? null,
    updated_at: new Date().toISOString(),
  });

  if (error) {
    return new Response(`upsert failed: ${error.message}`, { status: 500 });
  }

  return new Response('ok', { status: 200 });
});
