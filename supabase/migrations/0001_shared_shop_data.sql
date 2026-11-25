-- SHOPMASTER PRO shared-data foundation (Supabase / PostgreSQL)
create extension if not exists pgcrypto;
create table if not exists public.shops (
 id uuid primary key default gen_random_uuid(),
 name text not null check (length(trim(name)) between 1 and 120),
 created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now()
);
create table if not exists public.shop_members (
 shop_id uuid not null references public.shops(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check (role in ('owner','admin','staff','viewer')),
 created_at timestamptz not null default now(),
 primary key (shop_id,user_id)
);
create table if not exists public.shop_records (
 shop_id uuid not null references public.shops(id) on delete cascade,
 entity text not null check (entity in ('products','parties','invoices','invoice_items','serials','stock_movements','accounts','account_txns','expenses','party_payments','warranty_claims','settings','invoice_attachments')),
 record_id text not null check (length(record_id) between 1 and 160),
 data jsonb not null,
 revision bigint not null default 1 check (revision > 0),
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id) on delete set null,
 deleted_at timestamptz,
 primary key (shop_id,entity,record_id)
);
create index if not exists shop_records_sync_idx on public.shop_records(shop_id,updated_at,entity,record_id);
create index if not exists shop_records_live_idx on public.shop_records(shop_id,entity) where deleted_at is null;

create or replace function public.is_shop_member(target_shop uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.shop_members m where m.shop_id=target_shop and m.user_id=auth.uid());
$$;
create or replace function public.has_shop_role(target_shop uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.shop_members m where m.shop_id=target_shop and m.user_id=auth.uid() and m.role=any(allowed_roles));
$$;
revoke all on function public.is_shop_member(uuid) from public;
revoke all on function public.has_shop_role(uuid,text[]) from public;
grant execute on function public.is_shop_member(uuid) to authenticated;
grant execute on function public.has_shop_role(uuid,text[]) to authenticated;

create or replace function public.add_shop_creator_as_owner()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.shop_members(shop_id,user_id,role) values(new.id,new.created_by,'owner')
 on conflict(shop_id,user_id) do nothing;
 return new;
end;
$$;
drop trigger if exists shops_add_creator_owner on public.shops;
create trigger shops_add_creator_owner after insert on public.shops
for each row execute function public.add_shop_creator_as_owner();

create or replace function public.bump_shop_record_revision()
returns trigger language plpgsql set search_path=public as $$
begin
 new.revision:=old.revision+1;
 new.updated_at:=now();
 new.updated_by:=auth.uid();
 return new;
end;
$$;
drop trigger if exists shop_records_bump_revision on public.shop_records;
create trigger shop_records_bump_revision before update on public.shop_records
for each row execute function public.bump_shop_record_revision();

alter table public.shops enable row level security;
alter table public.shop_members enable row level security;
alter table public.shop_records enable row level security;

drop policy if exists "shop members can read their shops" on public.shops;
create policy "shop members can read their shops" on public.shops for select to authenticated using(public.is_shop_member(id));
drop policy if exists "authenticated users can create their own shop" on public.shops;
create policy "authenticated users can create their own shop" on public.shops for insert to authenticated with check(created_by=auth.uid());
drop policy if exists "shop admins can update shop details" on public.shops;
create policy "shop admins can update shop details" on public.shops for update to authenticated using(public.has_shop_role(id,array['owner','admin'])) with check(public.has_shop_role(id,array['owner','admin']));

drop policy if exists "members can read membership list" on public.shop_members;
create policy "members can read membership list" on public.shop_members for select to authenticated using(public.is_shop_member(shop_id));
drop policy if exists "shop admins can add members" on public.shop_members;
create policy "shop admins can add members" on public.shop_members for insert to authenticated with check(public.has_shop_role(shop_id,array['owner','admin']));
drop policy if exists "shop owners can change members" on public.shop_members;
create policy "shop owners can change members" on public.shop_members for update to authenticated using(public.has_shop_role(shop_id,array['owner'])) with check(public.has_shop_role(shop_id,array['owner']));
drop policy if exists "shop owners can remove members" on public.shop_members;
create policy "shop owners can remove members" on public.shop_members for delete to authenticated using(public.has_shop_role(shop_id,array['owner']));

drop policy if exists "members can read shop records" on public.shop_records;
create policy "members can read shop records" on public.shop_records for select to authenticated using(public.is_shop_member(shop_id));
drop policy if exists "members can create shop records" on public.shop_records;
create policy "members can create shop records" on public.shop_records for insert to authenticated with check(public.is_shop_member(shop_id) and updated_by=auth.uid());
drop policy if exists "members can update shop records" on public.shop_records;
create policy "members can update shop records" on public.shop_records for update to authenticated using(public.is_shop_member(shop_id)) with check(public.is_shop_member(shop_id));
drop policy if exists "members can delete shop records" on public.shop_records;
create policy "members can delete shop records" on public.shop_records for delete to authenticated using(public.is_shop_member(shop_id));
