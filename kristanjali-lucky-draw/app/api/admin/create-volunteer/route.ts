import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function POST(req: Request) {
  const auth = req.headers.get('authorization');
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !anonKey || !serviceKey || !auth?.startsWith('Bearer ')) {
    return NextResponse.json({ error: 'Unauthorised or server configuration missing' }, { status: 401 });
  }

  const token = auth.slice(7);
  // Validate the caller's access token with a client using the public anon key.
  const authClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: { user }, error: authError } = await authClient.auth.getUser(token);
  if (authError || !user) return NextResponse.json({ error: 'Unauthorised' }, { status: 401 });

  // Use the service-role client only for server-side profile lookup and account creation.
  const adminClient = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: adminProfile, error: profileCheckError } = await adminClient
    .from('profiles').select('role,active').eq('user_id', user.id).maybeSingle();
  if (profileCheckError) { console.error('Admin profile lookup failed:', profileCheckError); return NextResponse.json({ error: 'Unable to verify administrator profile', diagnostic: profileCheckError.message, code: profileCheckError.code }, { status: 500 }); }
  if (!adminProfile?.active || adminProfile.role !== 'admin') {
    return NextResponse.json({ error: 'Administrator access required' }, { status: 403 });
  }

  let body: any;
  try { body = await req.json(); } catch { return NextResponse.json({ error: 'Invalid request' }, { status: 400 }); }
  const full_name = String(body.full_name || '').trim();
  const username = String(body.username || '').trim().toLowerCase();
  const password = String(body.password || '');
  if (!full_name || !/^[a-z0-9._-]{3,32}$/.test(username) || password.length < 8) {
    return NextResponse.json({ error: 'Enter a name, a username (3–32 letters/numbers/._-), and password of at least 8 characters.' }, { status: 400 });
  }
  const email = `${username}@volunteer.kristanjali.invalid`;
  const { data: created, error: createError } = await adminClient.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name, username } });
  if (createError || !created.user) return NextResponse.json({ error: createError?.message || 'Account creation failed' }, { status: 400 });
  const { error: profileError } = await adminClient.from('profiles').insert({ user_id: created.user.id, full_name, username, role: 'volunteer', active: true });
  if (profileError) {
    await adminClient.auth.admin.deleteUser(created.user.id);
    return NextResponse.json({ error: profileError.message }, { status: 400 });
  }
  return NextResponse.json({ ok: true, username });
}
