-- Запускать после local_bootstrap.sql и миграции в пустой локальной БД.
-- Supabase Auth здесь имитируется; доставка писем и вход по HTTP не проверяются.
begin;
create function pg_temp.assert_true(ok boolean, message text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'FAIL: %', message; end if;
end;
$$;
create function pg_temp.expect_sqlstate(statement text, expected text) returns void language plpgsql as $$
declare actual text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics actual = returned_sqlstate;
    if actual = expected then return; end if;
    raise exception 'Expected %, got % for %', expected, actual, statement;
  end;
  raise exception 'Expected rejection %, but succeeded: %', expected, statement;
end;
$$;

select pg_temp.assert_true((select display_name = 'Existing' from public.profiles where user_id = '00000000-0000-4000-8000-000000000003'), 'existing Auth user backfilled');
set local role supabase_auth_admin;
insert into auth.users values
('00000000-0000-4000-8000-000000000001', '{"display_name":" Alice ","role":"admin"}'),
('00000000-0000-4000-8000-000000000002', '{"display_name":123}');
reset role;
select pg_temp.assert_true((select display_name = 'Alice' from public.profiles where user_id = '00000000-0000-4000-8000-000000000001'), 'registration trigger trims name');
select pg_temp.assert_true((select char_length(display_name) > 0 from public.profiles where user_id = '00000000-0000-4000-8000-000000000002'), 'bad metadata cannot break registration');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
insert into public.monthly_budgets(month, income_kopecks, limit_kopecks) values ('2026-10-01', 6000000, 5000000);
insert into public.planned_payments(id, title, amount_kopecks, start_on) values ('10000000-0000-4000-8000-000000000001', 'Internet', 70000, '2026-10-29');
insert into public.savings_goals(title, target_kopecks, next_contribution_on) values ('Laptop', 8000000, '2026-10-30');
insert into public.transactions(id, kind, amount_kopecks, title, category, occurred_on)
values ('20000000-0000-4000-8000-000000000001', 'income', 6000000, 'Salary', 'Work', '2026-10-29');
insert into public.transactions(kind, amount_kopecks, title, category, occurred_on, source, source_ref)
values ('expense', 45000, 'Coffee', 'Cafe', '2026-10-29', 'import', 'local-entry-123');
insert into public.transactions(kind, amount_kopecks, title, category, occurred_on, source, planned_payment_id, payment_on)
values ('expense', 70000, 'Internet', 'Home', '2026-10-29', 'planned_payment', '10000000-0000-4000-8000-000000000001', '2026-10-29');
update public.profiles set display_name = 'Alice updated';
update public.transactions set note = 'Updated' where kind = 'income';
select pg_temp.assert_true((select count(*) = 3 from public.transactions), 'owner sees all own transactions');
select pg_temp.assert_true((select sum(case when kind = 'income' then amount_kopecks else -amount_kopecks end) = 5885000 from public.transactions), 'exact income minus expenses');
select pg_temp.assert_true((select bool_and(updated_at >= created_at) from public.transactions), 'timestamp trigger');
select pg_temp.expect_sqlstate($q$insert into public.transactions(kind,amount_kopecks,title,category,occurred_on) values ('expense',-1,'Bad','Cafe','2026-10-29')$q$, '23514');
select pg_temp.expect_sqlstate($q$insert into public.transactions(kind,amount_kopecks,title,category,occurred_on,source,source_ref) values ('expense',45000,'Coffee','Cafe','2026-10-29','import','local-entry-123')$q$, '23505');
select pg_temp.expect_sqlstate($q$insert into public.transactions(kind,amount_kopecks,title,category,occurred_on,source,planned_payment_id,payment_on) values ('expense',70000,'Internet','Home','2026-10-29','planned_payment','10000000-0000-4000-8000-000000000001','2026-10-29')$q$, '23505');
select pg_temp.expect_sqlstate($q$insert into public.monthly_budgets(month) values ('2026-10-02')$q$, '23514');
select pg_temp.expect_sqlstate($q$insert into public.monthly_budgets(month) values ('2026-10-01')$q$, '23505');
select pg_temp.expect_sqlstate($q$update public.transactions set user_id='00000000-0000-4000-8000-000000000002'$q$, '42501');
select pg_temp.expect_sqlstate($q$delete from public.profiles$q$, '42501');

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
select pg_temp.assert_true((select count(*) = 1 from public.profiles), 'only own profile visible');
select pg_temp.assert_true((select count(*) = 0 from public.transactions), 'other transactions hidden');
select pg_temp.assert_true((select count(*) = 0 from public.monthly_budgets), 'other budgets hidden');
select pg_temp.assert_true((select count(*) = 0 from public.planned_payments), 'other plans hidden');
select pg_temp.assert_true((select count(*) = 0 from public.savings_goals), 'other goals hidden');
with changed as (update public.transactions set amount_kopecks=1 returning id)
select pg_temp.assert_true((select count(*) = 0 from changed), 'cannot update other transactions');
with removed as (delete from public.transactions returning id)
select pg_temp.assert_true((select count(*) = 0 from removed), 'cannot delete other transactions');
select pg_temp.expect_sqlstate($q$insert into public.transactions(user_id,kind,amount_kopecks,title,category,occurred_on) values ('00000000-0000-4000-8000-000000000001','expense',1,'Bad','Cafe','2026-10-29')$q$, '42501');
select pg_temp.expect_sqlstate($q$insert into public.transactions(kind,amount_kopecks,title,category,occurred_on,source,planned_payment_id,payment_on) values ('expense',70000,'Foreign plan','Home','2026-10-29','planned_payment','10000000-0000-4000-8000-000000000001','2026-10-29')$q$, '23503');
insert into public.transactions(kind,amount_kopecks,title,category,occurred_on,source,source_ref)
values ('expense',45000,'Coffee','Cafe','2026-10-29','import','local-entry-123');
select pg_temp.assert_true((select count(*) = 1 from public.transactions), 'same import key allowed for another user');

select set_config('request.jwt.claim.sub', '', true);
select pg_temp.assert_true((select count(*) = 0 from public.transactions), 'no subject means no rows');
select pg_temp.expect_sqlstate($q$insert into public.transactions(kind,amount_kopecks,title,category,occurred_on) values ('expense',1,'Bad','Cafe','2026-10-29')$q$, '42501');
set local role anon;
select pg_temp.expect_sqlstate('select * from public.transactions', '42501');
select pg_temp.expect_sqlstate('select * from public.profiles', '42501');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
delete from public.planned_payments;
select pg_temp.assert_true((select count(*) = 3 from public.transactions), 'deleting plan preserves history');
select pg_temp.assert_true((select planned_payment_id is null and payment_on='2026-10-29' from public.transactions where source='planned_payment'), 'plan deletion detaches link and keeps occurrence date');
reset role;
delete from auth.users where id='00000000-0000-4000-8000-000000000001';
select pg_temp.assert_true((select count(*) = 0 from public.profiles where user_id='00000000-0000-4000-8000-000000000001'), 'Auth deletion removes profile');
select pg_temp.assert_true((select count(*) = 0 from public.transactions where user_id='00000000-0000-4000-8000-000000000001'), 'Auth deletion removes owned operations');
select pg_temp.assert_true((select count(*) = 0 from public.monthly_budgets), 'Auth deletion removes budgets');
select pg_temp.assert_true((select count(*) = 0 from public.savings_goals), 'Auth deletion removes goals');
select pg_temp.assert_true((select count(*) = 1 from public.transactions), 'Auth deletion preserves another user data');
rollback;
select 'All SQL checks passed' as result;
