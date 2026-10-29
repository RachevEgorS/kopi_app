-- ТОЛЬКО для пустой локальной тестовой БД PostgreSQL.
-- НЕ запускать в Supabase: там роли, auth.users и auth.uid() уже существуют.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create role supabase_auth_admin nologin;
create schema auth;
create table auth.users (id uuid primary key, raw_user_meta_data jsonb);
create function auth.uid() returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to authenticated, anon, service_role, supabase_auth_admin;
grant insert on auth.users to supabase_auth_admin;
insert into auth.users values ('00000000-0000-4000-8000-000000000003', '{"display_name":"Existing"}');
