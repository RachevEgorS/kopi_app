-- Integration test against a local PostgreSQL instance. All test data rolls back.
begin;
insert into auth.users(id) values('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into public.monthly_budgets(month,planned_income_kopecks,carry_forward) values('2026-10-01',3000000,true);
insert into public.savings_goals(id,title,target_kopecks,next_contribution_on) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Goal',100000,'2026-10-30');
insert into public.goal_contributions(id,goal_id,amount_kopecks,contributed_on) values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',5000,'2026-10-30');
insert into public.user_progress(id) values('day:2026-10-30'),('badge:first');
insert into public.planned_payments(id,title,amount_kopecks,start_on) values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Internet',70000,'2026-10-30');
select public.record_bank_operation('{"id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","user_id":"11111111-1111-4111-8111-111111111111","kind":"expense","amount_kopecks":70000,"title":"Internet","category":"Payments","occurred_on":"2026-10-30","source_ref":"event-1","planned_payment_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","payment_on":"2026-10-30"}');
select public.record_bank_operation('{"id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","user_id":"11111111-1111-4111-8111-111111111111","kind":"expense","amount_kopecks":70000,"title":"Internet","category":"Payments","occurred_on":"2026-10-30","source_ref":"event-2","planned_payment_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","payment_on":"2026-10-30"}');
do $$ begin
  if (select count(*) from public.transactions)<>1 then raise exception 'Duplicate linked payment'; end if;
  if (select sum(amount_kopecks) from public.goal_contributions)<>5000 then raise exception 'Missing contribution'; end if;
  update public.profiles set reminders_enabled=false where user_id=auth.uid();
end $$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$ begin
  if exists(select 1 from public.transactions) or exists(select 1 from public.goal_contributions) or exists(select 1 from public.user_progress) then raise exception 'RLS leaked another account'; end if;
  begin
    insert into public.user_progress(user_id,id) values('11111111-1111-4111-8111-111111111111','day:2026-10-31');
    raise exception 'RLS allowed foreign progress';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.goal_contributions(goal_id,amount_kopecks,contributed_on) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',100,'2026-10-30');
    raise exception 'Foreign goal accepted';
  exception when foreign_key_violation then null; end;
  begin
    perform public.record_bank_operation('{"id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","user_id":"11111111-1111-4111-8111-111111111111"}');
    raise exception 'Foreign bank operation accepted';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
select 'RLS, linked-payment deduplication, contributions and progress: passed' as result;
