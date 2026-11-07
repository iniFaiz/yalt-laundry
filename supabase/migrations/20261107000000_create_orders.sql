-- =====================================================================
-- Pesanan laundry: orders, order_items, order_status_histories
-- beserta fungsi (RPC), trigger, view, RLS, dan Realtime.
--
-- Prinsip keamanan:
-- - Klien (anon/authenticated) hanya boleh SELECT; semua perubahan data pesanan
--   wajib lewat fungsi security definer yang memvalidasi role, harga, dan status.
-- - Kolom pickup_token tidak bisa dibaca langsung oleh siapa pun lewat API.
--   Pelanggan mengambil token miliknya lewat sp_get_pickup_token, admin hanya
--   menerima token dari hasil scan QR pelanggan.
-- - Kode error memakai SQLSTATE yang dipetakan PostgREST ke HTTP status:
--   42501 -> 403, 22023 -> 400, 23505 -> 409, PT404 -> 404, PT409 -> 409.
-- =====================================================================

-- estimasi lama pengerjaan per layanan, dipakai menghitung estimasi selesai pesanan
alter table public.services
  add column duration_hours integer not null default 48
  constraint services_duration_hours_check check (duration_hours between 1 and 720);

-- ---------------------------------------------------------------------
-- Fungsi subtotal: berat (kg) x tarif per kg, dibulatkan ke rupiah penuh.
-- immutable agar bisa dipakai sebagai generated column order_items.subtotal.
-- ---------------------------------------------------------------------
create or replace function public.fn_item_total(p_weight_kg numeric, p_price_per_kg numeric)
returns numeric
language sql
immutable
strict
parallel safe
as $$
  select round(p_weight_kg * p_price_per_kg, 0);
$$;

-- ---------------------------------------------------------------------
-- Tabel orders
-- ---------------------------------------------------------------------
-- nomor pesanan yang mudah dibaca manusia, contoh ORD-00001
create sequence public.order_code_seq;

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_code text not null default ('ORD-' || lpad(nextval('public.order_code_seq')::text, 5, '0')),
  customer_id uuid not null,
  status text not null default 'diterima',
  total_amount numeric(14, 2) not null default 0,
  notes text,
  estimated_completion_at timestamptz not null default now(),
  -- token QR acak 128-bit (122 bit acak dari gen_random_uuid), sekali pakai
  pickup_token text not null default replace(gen_random_uuid()::text, '-', ''),
  pickup_token_used_at timestamptz,
  picked_up_by uuid,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint orders_order_code_key unique (order_code),
  constraint orders_pickup_token_key unique (pickup_token),
  constraint orders_customer_id_fkey foreign key (customer_id) references public.profiles (id),
  constraint orders_picked_up_by_fkey foreign key (picked_up_by) references public.profiles (id) on delete set null,
  constraint orders_created_by_fkey foreign key (created_by) references public.profiles (id) on delete set null,
  constraint orders_status_check check (status in ('diterima', 'dicuci', 'siap_diambil', 'diambil')),
  constraint orders_total_amount_check check (total_amount >= 0),
  -- status diambil <=> token QR sudah dipakai (diambil tidak bisa dicapai tanpa QR)
  constraint orders_pickup_consistency_check check ((status = 'diambil') = (pickup_token_used_at is not null))
);

create index orders_customer_created_idx on public.orders (customer_id, created_at desc);
create index orders_active_created_idx on public.orders (created_at desc) where status <> 'diambil';

create trigger orders_set_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Tabel order_items (snapshot nama & tarif layanan saat pesanan dibuat)
-- ---------------------------------------------------------------------
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null,
  service_id uuid not null,
  service_name_snapshot text not null,
  weight_kg numeric(8, 2) not null,
  price_per_kg_snapshot numeric(12, 2) not null,
  subtotal numeric(14, 2) generated always as (public.fn_item_total(weight_kg, price_per_kg_snapshot)) stored,
  created_at timestamptz not null default now(),
  constraint order_items_order_id_fkey foreign key (order_id) references public.orders (id) on delete cascade,
  -- layanan yang sudah dipakai pesanan tidak bisa dihapus fisik (riwayat tetap utuh)
  constraint order_items_service_id_fkey foreign key (service_id) references public.services (id),
  constraint order_items_weight_kg_check check (weight_kg > 0 and weight_kg <= 100),
  constraint order_items_price_check check (price_per_kg_snapshot > 0)
);

create index order_items_order_id_idx on public.order_items (order_id);
create index order_items_service_id_idx on public.order_items (service_id);

-- ---------------------------------------------------------------------
-- Tabel order_status_histories (diisi otomatis oleh trigger)
-- ---------------------------------------------------------------------
create table public.order_status_histories (
  id bigint generated always as identity primary key,
  order_id uuid not null,
  from_status text,
  to_status text not null,
  changed_by uuid,
  changed_at timestamptz not null default now(),
  constraint order_status_histories_order_id_fkey foreign key (order_id) references public.orders (id) on delete cascade,
  constraint order_status_histories_changed_by_fkey foreign key (changed_by) references public.profiles (id) on delete set null,
  constraint order_status_histories_to_status_check check (to_status in ('diterima', 'dicuci', 'siap_diambil', 'diambil'))
);

create index order_status_histories_order_idx on public.order_status_histories (order_id, changed_at);

-- ---------------------------------------------------------------------
-- Trigger validasi alur status (berlaku juga untuk update langsung dari dashboard)
-- diterima -> dicuci -> siap_diambil -> diambil, tidak boleh lompat / mundur.
-- ---------------------------------------------------------------------
create or replace function public.trg_orders_validate_status()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_flow constant text[] := array['diterima', 'dicuci', 'siap_diambil', 'diambil'];
begin
  if tg_op = 'INSERT' then
    if new.status <> 'diterima' then
      raise exception 'Pesanan baru harus berstatus diterima'
        using errcode = 'PT409', hint = 'invalid_transition';
    end if;
    return new;
  end if;

  if new.status is distinct from old.status then
    if array_position(v_flow, new.status) is distinct from array_position(v_flow, old.status) + 1 then
      raise exception 'Transisi status % -> % tidak valid', old.status, new.status
        using errcode = 'PT409', hint = 'invalid_transition';
    end if;
    if new.status = 'diambil' and new.pickup_token_used_at is null then
      raise exception 'Status diambil hanya bisa dicapai melalui scan QR pengambilan'
        using errcode = 'PT409', hint = 'pickup_requires_qr';
    end if;
  end if;
  return new;
end;
$$;

create trigger orders_validate_status
before insert or update on public.orders
for each row execute function public.trg_orders_validate_status();

-- catat setiap perubahan status ke order_status_histories
create or replace function public.trg_orders_log_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.order_status_histories (order_id, from_status, to_status, changed_by)
    values (
      new.id,
      case when tg_op = 'UPDATE' then old.status end,
      new.status,
      auth.uid()
    );
  end if;
  return null;
end;
$$;

create trigger orders_log_status
after insert or update on public.orders
for each row execute function public.trg_orders_log_status();

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_histories enable row level security;

create policy "Pelanggan melihat pesanan sendiri, admin melihat semua"
on public.orders
for select
to authenticated
using (customer_id = (select auth.uid()) or (select public.is_admin()));

create policy "Item pesanan mengikuti hak akses pesanan"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and (o.customer_id = (select auth.uid()) or (select public.is_admin()))
  )
);

create policy "Riwayat status mengikuti hak akses pesanan"
on public.order_status_histories
for select
to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_status_histories.order_id
      and (o.customer_id = (select auth.uid()) or (select public.is_admin()))
  )
);

-- Klien hanya boleh membaca. Tulis data wajib lewat RPC di bawah.
revoke all on public.orders, public.order_items, public.order_status_histories from anon, authenticated;
revoke all on sequence public.order_code_seq from anon, authenticated;

-- pickup_token sengaja tidak termasuk (hak akses per kolom)
grant select (
  id, order_code, customer_id, status, total_amount, notes, estimated_completion_at,
  pickup_token_used_at, picked_up_by, created_by, created_at, updated_at
) on public.orders to authenticated;
grant select on public.order_items, public.order_status_histories to authenticated;

-- ---------------------------------------------------------------------
-- Helper: baris pesanan -> JSON tanpa pickup_token
-- ---------------------------------------------------------------------
create or replace function public.fn_order_public_json(p_order public.orders)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select to_jsonb(p_order) - 'pickup_token';
$$;

-- ---------------------------------------------------------------------
-- RPC: buat pesanan + semua item secara atomik
-- p_items: [{"service_id": "<uuid>", "weight_kg": 2.5}, ...]
-- Jika satu item gagal, seluruh pesanan dibatalkan (satu transaksi).
-- ---------------------------------------------------------------------
create or replace function public.sp_create_order(
  p_customer_id uuid,
  p_items jsonb,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_item jsonb;
  v_service public.services;
  v_service_id uuid;
  v_weight numeric;
  v_max_hours integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat membuat pesanan' using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles where id = p_customer_id and role = 'customer') then
    raise exception 'Pelanggan tidak ditemukan' using errcode = 'PT404', hint = 'customer_not_found';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Pesanan minimal berisi satu layanan' using errcode = '22023', hint = 'empty_items';
  end if;
  if jsonb_array_length(p_items) > 20 then
    raise exception 'Satu pesanan maksimal berisi 20 layanan' using errcode = '22023', hint = 'too_many_items';
  end if;

  insert into public.orders (customer_id, notes, created_by)
  values (p_customer_id, nullif(trim(p_notes), ''), auth.uid())
  returning * into v_order;

  for v_item in select value from jsonb_array_elements(p_items) loop
    begin
      v_service_id := (v_item ->> 'service_id')::uuid;
      v_weight := (v_item ->> 'weight_kg')::numeric;
    exception when others then
      raise exception 'Format item pesanan tidak valid' using errcode = '22023', hint = 'invalid_item';
    end;

    if v_weight is null or v_weight <= 0 or v_weight > 100 then
      raise exception 'Berat cucian harus lebih dari 0 dan maksimal 100 kg' using errcode = '22023', hint = 'invalid_weight';
    end if;

    -- kunci baris layanan agar tarif tidak berubah di tengah transaksi
    select * into v_service from public.services where id = v_service_id for share;
    if not found or not v_service.is_active then
      raise exception 'Layanan tidak ditemukan atau sudah nonaktif' using errcode = '22023', hint = 'service_unavailable';
    end if;

    insert into public.order_items (order_id, service_id, service_name_snapshot, weight_kg, price_per_kg_snapshot)
    values (v_order.id, v_service.id, v_service.name, v_weight, v_service.price_per_kg);

    v_max_hours := greatest(v_max_hours, v_service.duration_hours);
  end loop;

  -- total = jumlah fn_item_total tiap item (memakai snapshot tarif)
  update public.orders o
  set total_amount = (
        select coalesce(sum(public.fn_item_total(i.weight_kg, i.price_per_kg_snapshot)), 0)
        from public.order_items i
        where i.order_id = o.id
      ),
      estimated_completion_at = o.created_at + make_interval(hours => v_max_hours)
  where o.id = v_order.id
  returning * into v_order;

  return public.fn_order_public_json(v_order);
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: ubah status pesanan (admin). Hanya maju satu langkah.
-- Status diambil ditolak di sini: wajib lewat sp_pickup_order (scan QR).
-- ---------------------------------------------------------------------
create or replace function public.sp_update_order_status(p_order_id uuid, p_new_status text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_flow constant text[] := array['diterima', 'dicuci', 'siap_diambil', 'diambil'];
  v_order public.orders;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat mengubah status pesanan' using errcode = '42501';
  end if;

  if p_new_status is null or not (p_new_status = any (v_flow)) then
    raise exception 'Status % tidak dikenal', coalesce(p_new_status, 'null') using errcode = '22023', hint = 'unknown_status';
  end if;

  if p_new_status = 'diambil' then
    raise exception 'Status diambil hanya bisa dicapai melalui scan QR pengambilan'
      using errcode = 'PT409', hint = 'pickup_requires_qr';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Pesanan tidak ditemukan' using errcode = 'PT404', hint = 'order_not_found';
  end if;

  if array_position(v_flow, p_new_status) is distinct from array_position(v_flow, v_order.status) + 1 then
    raise exception 'Transisi status % -> % tidak valid', v_order.status, p_new_status
      using errcode = 'PT409', hint = 'invalid_transition';
  end if;

  update public.orders set status = p_new_status where id = p_order_id
  returning * into v_order;

  return public.fn_order_public_json(v_order);
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: pelanggan mengambil token QR pesanan miliknya sendiri
-- ---------------------------------------------------------------------
create or replace function public.sp_get_pickup_token(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
begin
  select * into v_order from public.orders
  where id = p_order_id and customer_id = auth.uid();
  if not found then
    raise exception 'Pesanan tidak ditemukan' using errcode = 'PT404', hint = 'order_not_found';
  end if;

  return jsonb_build_object(
    'order_id', v_order.id,
    'status', v_order.status,
    -- token tidak dikirim lagi setelah dipakai
    'pickup_token', case when v_order.pickup_token_used_at is null then v_order.pickup_token end,
    'pickup_token_used_at', v_order.pickup_token_used_at
  );
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: admin memproses scan QR pengambilan.
-- Validasi + tandai token terpakai secara atomik dengan row lock (FOR UPDATE),
-- sehingga dua scan bersamaan tidak bisa sama-sama berhasil.
-- ---------------------------------------------------------------------
create or replace function public.sp_pickup_order(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat memproses pengambilan' using errcode = '42501';
  end if;

  if p_token is null or length(trim(p_token)) = 0 then
    raise exception 'Token QR kosong' using errcode = '22023', hint = 'empty_token';
  end if;

  -- request kedua menunggu di sini sampai request pertama selesai (commit)
  select * into v_order from public.orders where pickup_token = trim(p_token) for update;
  if not found then
    raise exception 'QR tidak dikenali' using errcode = 'PT404', hint = 'token_not_found';
  end if;

  if v_order.pickup_token_used_at is not null then
    raise exception 'QR sudah pernah dipakai pada %',
      to_char(v_order.pickup_token_used_at at time zone 'Asia/Jakarta', 'DD-MM-YYYY HH24:MI')
      using errcode = 'PT409', hint = 'token_used';
  end if;

  if v_order.status <> 'siap_diambil' then
    raise exception 'Cucian belum siap diambil (status: %)', v_order.status
      using errcode = 'PT409', hint = 'not_ready';
  end if;

  update public.orders
  set status = 'diambil',
      pickup_token_used_at = now(),
      picked_up_by = auth.uid()
  where id = v_order.id
  returning * into v_order;

  return public.fn_order_public_json(v_order);
end;
$$;

-- ---------------------------------------------------------------------
-- Views (security_invoker: RLS tabel asal tetap berlaku untuk pemanggil)
-- ---------------------------------------------------------------------
-- ringkasan pesanan aktif (belum diambil)
create view public.active_orders_view
with (security_invoker = true) as
select
  o.id,
  o.order_code,
  o.customer_id,
  p.full_name as customer_name,
  p.phone as customer_phone,
  o.status,
  o.total_amount,
  o.estimated_completion_at,
  o.created_at,
  count(i.id) as item_count,
  coalesce(sum(i.weight_kg), 0) as total_weight_kg,
  string_agg(i.service_name_snapshot, ', ' order by i.created_at) as services
from public.orders o
join public.profiles p on p.id = o.customer_id
left join public.order_items i on i.order_id = o.id
where o.status <> 'diambil'
group by o.id, p.id;

-- laporan harian sederhana (zona waktu WIB)
create view public.daily_order_report_view
with (security_invoker = true) as
select
  (o.created_at at time zone 'Asia/Jakarta')::date as order_date,
  count(*) as order_count,
  count(*) filter (where o.status = 'diambil') as completed_count,
  coalesce(sum(w.total_weight_kg), 0) as total_weight_kg,
  sum(o.total_amount) as gross_amount,
  coalesce(sum(o.total_amount) filter (where o.status = 'diambil'), 0) as collected_amount
from public.orders o
left join (
  select order_id, sum(weight_kg) as total_weight_kg
  from public.order_items
  group by order_id
) w on w.order_id = o.id
group by 1;

revoke all on public.active_orders_view, public.daily_order_report_view from anon, authenticated;
grant select on public.active_orders_view, public.daily_order_report_view to authenticated;

-- ---------------------------------------------------------------------
-- Hak eksekusi fungsi: hanya pengguna login (pengecekan role ada di dalam fungsi)
-- ---------------------------------------------------------------------
revoke execute on function public.sp_create_order(uuid, jsonb, text) from public, anon;
revoke execute on function public.sp_update_order_status(uuid, text) from public, anon;
revoke execute on function public.sp_get_pickup_token(uuid) from public, anon;
revoke execute on function public.sp_pickup_order(text) from public, anon;
revoke execute on function public.fn_order_public_json(public.orders) from public, anon, authenticated;
revoke execute on function public.trg_orders_validate_status() from public, anon, authenticated;
revoke execute on function public.trg_orders_log_status() from public, anon, authenticated;

grant execute on function public.sp_create_order(uuid, jsonb, text) to authenticated;
grant execute on function public.sp_update_order_status(uuid, text) to authenticated;
grant execute on function public.sp_get_pickup_token(uuid) to authenticated;
grant execute on function public.sp_pickup_order(text) to authenticated;
grant execute on function public.fn_item_total(numeric, numeric) to anon, authenticated;

-- ---------------------------------------------------------------------
-- Realtime: aplikasi pelanggan memuat ulang status saat pesanan berubah
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.orders;
  end if;
end;
$$;
