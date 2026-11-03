-- Упрощённый план и индивидуальное расписание напоминаний.
begin;
alter table public.monthly_budgets add column if not exists simple_plan boolean not null default false;
alter table public.planned_payments add column if not exists reminder_minute integer not null default 540 check (reminder_minute between 0 and 1439);
alter table public.planned_payments add column if not exists repeat_minutes integer not null default 0 check (repeat_minutes in (0,15,30,60,1440));
commit;
