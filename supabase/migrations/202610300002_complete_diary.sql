-- Копи: дополнение к первой схеме. Выполнить в SQL Editor существующего проекта.
-- Существующие операции, бюджеты и цели сохраняются.
begin;
alter table public.monthly_budgets add column if not exists planned_income_kopecks bigint not null default 0 check (planned_income_kopecks between 0 and 99999999999);
alter table public.monthly_budgets add column if not exists carry_forward boolean not null default false;
alter table public.transactions add column if not exists income_in_opening boolean not null default false;
alter table public.transactions drop constraint if exists income_in_opening_kind;
alter table public.transactions add constraint income_in_opening_kind check (not income_in_opening or kind = 'income');
alter table public.transactions drop constraint if exists payment_source;
alter table public.transactions add constraint payment_source check (planned_payment_id is null or source in ('planned_payment', 'notification'));
create unique index if not exists savings_goals_owner_id on public.savings_goals(user_id, id);

create table if not exists public.goal_contributions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  goal_id uuid not null,
  amount_kopecks bigint not null check (amount_kopecks between 1 and 99999999999),
  contributed_on date not null check (isfinite(contributed_on)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (user_id, goal_id) references public.savings_goals(user_id, id) on delete cascade
);
create table if not exists public.user_progress (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (char_length(id) between 1 and 160),
  value boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
do $$
declare t text;
begin
  foreach t in array array['goal_contributions', 'user_progress'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop policy if exists owner_access on public.%I', t);
    execute format('create policy owner_access on public.%I for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
    execute format('drop trigger if exists touch_row on public.%I', t);
    execute format('create trigger touch_row before update on public.%I for each row execute function kopi_private.touch_row()', t);
  end loop;
end $$;

-- Запись из банка и отметка оплаты: один запрос, одна транзакция, RLS действует.
create or replace function public.record_bank_operation(operation jsonb)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  actor uuid := auth.uid();
  operation_id uuid := (operation->>'id')::uuid;
  payment_id uuid := nullif(operation->>'planned_payment_id','')::uuid;
  payment_date date := nullif(operation->>'payment_on','')::date;
  existing_id uuid;
  existing_amount bigint;
begin
  if actor is null or actor is distinct from (operation->>'user_id')::uuid then
    raise exception 'Wrong owner' using errcode = '42501';
  end if;
  if payment_id is not null then
    -- Serialize a bank confirmation with other bank confirmations of this occurrence.
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text || payment_id::text || payment_date::text, 0));
    select id, amount_kopecks into existing_id, existing_amount from public.transactions
      where user_id = actor and planned_payment_id = payment_id and payment_on = payment_date;
    if existing_id is not null then
      if existing_amount <> (operation->>'amount_kopecks')::bigint then
        raise exception 'Payment already recorded with a different amount' using errcode = '23505';
      end if;
      return existing_id;
    end if;
  end if;
  begin
    insert into public.transactions(id,user_id,kind,amount_kopecks,title,category,occurred_on,source,source_ref,planned_payment_id,payment_on,income_in_opening)
    values(operation_id,actor,operation->>'kind',(operation->>'amount_kopecks')::bigint,operation->>'title',operation->>'category',
      (operation->>'occurred_on')::date,'notification',operation->>'source_ref',payment_id,payment_date,coalesce((operation->>'income_in_opening')::boolean,false))
    on conflict(id) do nothing;
  exception when unique_violation then
    select id,amount_kopecks into existing_id,existing_amount from public.transactions
      where user_id=actor and planned_payment_id=payment_id and payment_on=payment_date;
    if existing_id is null or existing_amount <> (operation->>'amount_kopecks')::bigint then raise; end if;
    return existing_id;
  end;
  if not exists(select 1 from public.transactions where id=operation_id and user_id=actor) then
    raise exception 'Wrong owner' using errcode='42501';
  end if;
  return operation_id;
end $$;
revoke all on function public.record_bank_operation(jsonb) from public, anon;
grant execute on function public.record_bank_operation(jsonb) to authenticated;
commit;
