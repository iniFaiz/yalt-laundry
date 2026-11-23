-- =====================================================================
-- Hardening & optimasi database (23 Nov 2026):
-- 1. sp_get_pickup_token: hanya kirim token saat status = siap_diambil
--    (defense-in-depth, bukan hanya dicek di UI dan sp_pickup_order).
-- 2. Batas panjang teks (notes, services.name, profiles.full_name).
-- 3. Perbaiki default order_code agar tidak terpotong pada pesanan >= 100.000.
-- 4. Optimasi RLS InitPlan di profiles & services (bungkus auth.uid() &
--    is_admin() dengan SELECT agar dievaluasi sekali per query).
-- 5. Tambah index orders (created_at desc) untuk riwayat & monitoring admin.
-- 6. Batasi daftar kolom publication supabase_realtime tanpa pickup_token.
-- =====================================================================

-- 1. Perketat sp_get_pickup_token: token hanya keluar saat siap_diambil & belum dipakai
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
    -- token hanya dikirim ketika pesanan benar-benar siap diambil dan belum dipakai
    'pickup_token', case
      when v_order.status = 'siap_diambil' and v_order.pickup_token_used_at is null
        then v_order.pickup_token
    end,
    'pickup_token_used_at', v_order.pickup_token_used_at
  );
end;
$$;

-- 2. Batas panjang teks (mencegah payload besar lewat panggilan API langsung)
alter table public.orders
  drop constraint if exists orders_notes_length_check,
  add constraint orders_notes_length_check check (notes is null or length(notes) <= 500);

alter table public.services
  drop constraint if exists services_name_length_check,
  add constraint services_name_length_check check (length(trim(name)) <= 100);

alter table public.profiles
  drop constraint if exists profiles_full_name_length_check,
  add constraint profiles_full_name_length_check check (length(trim(full_name)) <= 100);

create or replace function public.fn_validate_customer_input(p_full_name text, p_phone text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_full_name is null or length(trim(p_full_name)) < 3 then
    raise exception 'Nama minimal 3 huruf' using errcode = '22023', hint = 'invalid_name';
  end if;
  if length(trim(p_full_name)) > 100 then
    raise exception 'Nama maksimal 100 huruf' using errcode = '22023', hint = 'invalid_name';
  end if;
  if p_phone is null or trim(p_phone) !~ '^08[0-9]{8,11}$' then
    raise exception 'Nomor HP harus diawali 08 dan berisi 10-13 angka' using errcode = '22023', hint = 'invalid_phone';
  end if;
end;
$$;

revoke execute on function public.fn_validate_customer_input(text, text) from public, anon, authenticated;

-- validasi panjang catatan juga di sp_create_order agar error berbahasa Indonesia (22023)
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
  v_notes text := nullif(trim(p_notes), '');
  v_max_hours integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat membuat pesanan' using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles where id = p_customer_id and role = 'customer') then
    raise exception 'Pelanggan tidak ditemukan' using errcode = 'PT404', hint = 'customer_not_found';
  end if;

  if v_notes is not null and length(v_notes) > 500 then
    raise exception 'Catatan maksimal 500 karakter' using errcode = '22023', hint = 'notes_too_long';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Pesanan minimal berisi satu layanan' using errcode = '22023', hint = 'empty_items';
  end if;
  if jsonb_array_length(p_items) > 20 then
    raise exception 'Satu pesanan maksimal berisi 20 layanan' using errcode = '22023', hint = 'too_many_items';
  end if;

  insert into public.orders (customer_id, notes, created_by)
  values (p_customer_id, v_notes, auth.uid())
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

-- 3. Nomor pesanan aman untuk angka >= 100.000 (tidak terpotong oleh lpad)
create or replace function public.fn_next_order_code()
returns text
language sql
set search_path = ''
as $$
  select 'ORD-' || case
    when n >= 100000 then n::text
    else lpad(n::text, 5, '0')
  end
  from (select nextval('public.order_code_seq') as n) s;
$$;

revoke execute on function public.fn_next_order_code() from public, anon, authenticated;

alter table public.orders
  alter column order_code set default public.fn_next_order_code();

-- 4. Optimasi RLS InitPlan pada profiles dan services (dievaluasi sekali per query)
drop policy if exists "Pengguna melihat profil sendiri, admin melihat semua" on public.profiles;
create policy "Pengguna melihat profil sendiri, admin melihat semua"
on public.profiles
for select
to authenticated
using (id = (select auth.uid()) or (select public.is_admin()));

drop policy if exists "Admin dapat menambah layanan" on public.services;
create policy "Admin dapat menambah layanan"
on public.services
for insert
to authenticated
with check ((select public.is_admin()));

drop policy if exists "Admin dapat mengubah layanan" on public.services;
create policy "Admin dapat mengubah layanan"
on public.services
for update
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists "Admin dapat menghapus layanan" on public.services;
create policy "Admin dapat menghapus layanan"
on public.services
for delete
to authenticated
using ((select public.is_admin()));

-- 5. Index untuk daftar semua pesanan / riwayat selesai admin
create index if not exists orders_created_at_idx on public.orders (created_at desc);

-- 6. Defense-in-depth Realtime: kecualikan pickup_token dari publication WAL
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders'
  ) then
    alter publication supabase_realtime drop table public.orders;
    alter publication supabase_realtime add table public.orders (
      id, order_code, customer_id, status, total_amount, notes,
      estimated_completion_at, pickup_token_used_at, picked_up_by,
      created_by, created_at, updated_at
    );
  end if;
end;
$$;
