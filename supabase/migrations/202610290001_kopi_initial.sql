-- Копи: Supabase / PostgreSQL 15+.
-- Выполнить ОДИН РАЗ в SQL Editor нового проекта Supabase.
-- Auth уже существует в Supabase: этот файл не создаёт пароли или сессии.
-- Если одноимённые таблицы уже есть, транзакция отменится без удаления данных.

begin;

create schema kopi_private;
revoke all on schema kopi_private from public, anon, authenticated;

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Друг'
    check (char_length(btrim(display_name)) between 1 and 80),
  reminders_enabled boolean not null default true,
  support_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.monthly_budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  month date not null check (isfinite(month) and extract(day from month) = 1),
  -- Уже доступные деньги, а не ещё не полученная зарплата.
  income_kopecks bigint not null default 0 check (income_kopecks between 0 and 99999999999),
  limit_kopecks bigint not null default 0 check (limit_kopecks between 0 and 99999999999),
  reserve_kopecks bigint not null default 0 check (reserve_kopecks between 0 and 99999999999),
  dreams_kopecks bigint not null default 0 check (dreams_kopecks between 0 and 99999999999),
  currency text not null default 'RUB' check (currency = 'RUB'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, month)
);

create table public.planned_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 160),
  amount_kopecks bigint not null check (amount_kopecks between 1 and 99999999999),
  start_on date not null check (isfinite(start_on)),
  monthly boolean not null default false,
  reminder_days integer not null default 1 check (reminder_days between -1 and 365),
  currency text not null default 'RUB' check (currency = 'RUB'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Составной ключ нужен для запрета привязки чужого платежа к своей операции.
  unique (user_id, id)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('income', 'expense')),
  amount_kopecks bigint not null check (amount_kopecks between 1 and 99999999999),
  currency text not null default 'RUB' check (currency = 'RUB'),
  title text not null check (char_length(btrim(title)) between 1 and 160),
  category text not null check (char_length(btrim(category)) between 1 and 80),
  note text not null default '' check (char_length(note) <= 2000),
  -- Календарная дата с устройства; не сдвигается при смене часового пояса.
  occurred_on date not null check (isfinite(occurred_on)),
  -- Точный момент, если известен. Для ручной записи можно оставить NULL.
  occurred_at timestamptz,
  source text not null default 'manual'
    check (source in ('manual', 'planned_payment', 'notification', 'import')),
  -- Стабильный ключ импорта/уведомления. Повтор с тем же ключом запрещён.
  source_ref text check (char_length(btrim(source_ref)) between 1 and 300),
  planned_payment_id uuid,
  payment_on date check (isfinite(payment_on)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payment_requires_date check (planned_payment_id is null or payment_on is not null),
  constraint payment_is_expense check (payment_on is null or kind = 'expense'),
  constraint payment_source check (planned_payment_id is null or source = 'planned_payment'),
  constraint payment_owner foreign key (user_id, planned_payment_id)
    references public.planned_payments(user_id, id)
    -- Удаление плана сохраняет историю расходов и владельца операции.
    on delete set null (planned_payment_id)
);

create index transactions_user_date_idx on public.transactions(user_id, occurred_on desc, created_at desc);
create index transactions_user_kind_category_idx on public.transactions(user_id, kind, category, occurred_on);
create unique index transactions_source_ref_unique on public.transactions(user_id, source, source_ref)
  where source_ref is not null;
create unique index transactions_payment_unique on public.transactions(user_id, planned_payment_id, payment_on)
  where planned_payment_id is not null;

create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 70),
  target_kopecks bigint not null check (target_kopecks between 1 and 99999999999),
  saved_kopecks bigint not null default 0 check (saved_kopecks between 0 and 99999999999),
  weekly_kopecks bigint not null default 0 check (weekly_kopecks between 0 and 99999999999),
  next_contribution_on date not null check (isfinite(next_contribution_on)),
  icon text not null default 'laptop' check (char_length(btrim(icon)) between 1 and 80),
  currency text not null default 'RUB' check (currency = 'RUB'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index savings_goals_user_idx on public.savings_goals(user_id);

-- Сервер обновляет время изменения и запрещает смену владельца.
create function kopi_private.touch_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'Changing the owner is not allowed' using errcode = '42501';
  end if;
  new.created_at := old.created_at;
  new.updated_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;
revoke all on function kopi_private.touch_row() from public, anon, authenticated;

-- Профиль создаётся автоматически после регистрации через Supabase Auth.
-- Метаданные применяются только к имени, не к правам доступа.
create function kopi_private.create_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(user_id, display_name)
  values (
    new.id,
    case when pg_catalog.jsonb_typeof(new.raw_user_meta_data -> 'display_name') = 'string'
      then coalesce(nullif(pg_catalog.left(pg_catalog.btrim(new.raw_user_meta_data ->> 'display_name'), 80), ''), 'Друг')
      else 'Друг'
    end
  );
  return new;
end;
$$;
revoke all on function kopi_private.create_profile() from public, anon, authenticated;

create trigger kopi_create_profile
after insert on auth.users
for each row execute function kopi_private.create_profile();

-- Для аккаунтов, созданных в Authentication до выполнения этого скрипта.
insert into public.profiles(user_id, display_name)
select id,
  case when jsonb_typeof(raw_user_meta_data -> 'display_name') = 'string'
    then coalesce(nullif(left(btrim(raw_user_meta_data ->> 'display_name'), 80), ''), 'Друг')
    else 'Друг'
  end
from auth.users
on conflict (user_id) do nothing;

-- RLS: отдельные правила чтения/создания/изменения/удаления.
-- Охватывают ВСЕ таблицы приложения; anon не получает доступа.
do $$
declare table_name text;
begin
  foreach table_name in array array['profiles', 'monthly_budgets', 'planned_payments', 'transactions', 'savings_goals']
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
    execute format('grant select on table public.%I to authenticated', table_name);
    execute format('grant select, insert, update, delete on table public.%I to service_role', table_name);
    execute format('create policy own_select on public.%I for select to authenticated using ((select auth.uid()) = user_id)', table_name);
    execute format('create policy own_update on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', table_name);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function kopi_private.touch_row()', table_name);
    if table_name <> 'profiles' then
      execute format('grant insert, update, delete on table public.%I to authenticated', table_name);
      execute format('create policy own_insert on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', table_name);
      execute format('create policy own_delete on public.%I for delete to authenticated using ((select auth.uid()) = user_id)', table_name);
    end if;
  end loop;
end;
$$;

-- Сам профиль нельзя удалить/создать через клиент: им управляет Auth-триггер.
grant update(display_name, reminders_enabled, support_enabled) on public.profiles to authenticated;
grant usage on schema public to authenticated, service_role;

comment on column public.transactions.amount_kopecks is 'Положительная сумма в копейках: 45000 = 450 рублей; знак задаётся kind.';
comment on column public.transactions.source_ref is 'Ключ дедупликации в пределах пользователя и source. Сам импорт здесь не реализован.';
comment on column public.monthly_budgets.income_kopecks is 'Деньги уже в распоряжении. Дополнительные поступления — transactions.kind=income.';
comment on column public.planned_payments.reminder_days is '-1: выключено; 0: в день платежа; N: за N дней. Не запускает отправку уведомлений.';
comment on table public.savings_goals is 'Учёт целей и вручную отмеченных накоплений. Автоматических переводов денег нет.';

commit;
