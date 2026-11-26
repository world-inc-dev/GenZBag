-- GenZBag: atomic database-backed rate limiting for public Edge Functions.
-- Apply this migration in Supabase SQL Editor before deploying the updated functions.
-- Keys are SHA-256 hashes created server-side; raw IP addresses are not stored.

create schema if not exists private;

create table if not exists private.edge_rate_limits (
  key_hash text primary key check (length(key_hash) = 64),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count >= 1),
  updated_at timestamptz not null default now()
);

revoke all on schema private from public, anon, authenticated;
revoke all on table private.edge_rate_limits from public, anon, authenticated;

create or replace function public.consume_edge_rate_limit(
  p_key_hash text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare
  v_count integer;
  v_now timestamptz := clock_timestamp();
begin
  if p_key_hash is null or length(p_key_hash) <> 64
     or p_key_hash !~ '^[0-9a-f]{64}
    raise exception 'Invalid rate-limit parameters';
  end if;

  insert into private.edge_rate_limits as current_limit
    (key_hash, window_started_at, request_count, updated_at)
  values (p_key_hash, v_now, 1, v_now)
  on conflict (key_hash) do update
    set window_started_at = case
          when current_limit.window_started_at <= v_now - make_interval(secs => p_window_seconds)
          then v_now else current_limit.window_started_at end,
        request_count = case
          when current_limit.window_started_at <= v_now - make_interval(secs => p_window_seconds)
          then 1 else current_limit.request_count + 1 end,
        updated_at = v_now
  returning request_count into v_count;

  -- Opportunistically prune expired hashes so the limiter table stays bounded.
  if random() < 0.01 then
    delete from private.edge_rate_limits
    where updated_at < v_now - interval '2 days';
  end if;

  return v_count <= p_limit;
end;
$;

create or replace function public.consume_signup_availability_rate_limit(p_ip_hash text)
returns boolean
language sql
security definer
set search_path = pg_catalog, public
as $$
  select public.consume_edge_rate_limit(p_ip_hash, 20, 900);
$$;

revoke all on function public.consume_edge_rate_limit(text, integer, integer) from public, anon, authenticated;
revoke all on function public.consume_signup_availability_rate_limit(text) from public, anon, authenticated;
grant execute on function public.consume_edge_rate_limit(text, integer, integer) to service_role;
grant execute on function public.consume_signup_availability_rate_limit(text) to service_role;

-- Keep the table bounded: stale entries are safe to remove periodically.
create index if not exists edge_rate_limits_updated_at_idx
  on private.edge_rate_limits (updated_at);

     or p_limit is null or p_limit < 1 or p_limit > 10000
     or p_window_seconds is null or p_window_seconds < 1 or p_window_seconds > 86400 then
    raise exception 'Invalid rate-limit parameters';
  end if;

  insert into private.edge_rate_limits as current_limit
    (key_hash, window_started_at, request_count, updated_at)
  values (p_key_hash, v_now, 1, v_now)
  on conflict (key_hash) do update
    set window_started_at = case
          when current_limit.window_started_at <= v_now - make_interval(secs => p_window_seconds)
          then v_now else current_limit.window_started_at end,
        request_count = case
          when current_limit.window_started_at <= v_now - make_interval(secs => p_window_seconds)
          then 1 else current_limit.request_count + 1 end,
        updated_at = v_now
  returning request_count into v_count;

  -- Opportunistically prune expired hashes so the limiter table stays bounded.
  if random() < 0.01 then
    delete from private.edge_rate_limits
    where updated_at < v_now - interval '2 days';
  end if;

  return v_count <= p_limit;
end;
$;

create or replace function public.consume_signup_availability_rate_limit(p_ip_hash text)
returns boolean
language sql
security definer
set search_path = pg_catalog, public
as $$
  select public.consume_edge_rate_limit(p_ip_hash, 20, 900);
$$;

revoke all on function public.consume_edge_rate_limit(text, integer, integer) from public, anon, authenticated;
revoke all on function public.consume_signup_availability_rate_limit(text) from public, anon, authenticated;
grant execute on function public.consume_edge_rate_limit(text, integer, integer) to service_role;
grant execute on function public.consume_signup_availability_rate_limit(text) to service_role;

-- Keep the table bounded: stale entries are safe to remove periodically.
create index if not exists edge_rate_limits_updated_at_idx
  on private.edge_rate_limits (updated_at);
