-- =====================================================================
-- Kelola akun pelanggan oleh admin + hapus layanan yang aman.
--
-- Akun pelanggan dibuat langsung di auth.users (sama seperti seed.sql) oleh
-- fungsi security definer, jadi admin bisa mendaftarkan pelanggan dari aplikasi
-- tanpa Edge Function dan tanpa membuka pendaftaran publik.
-- Login aplikasi: nomor HP dipetakan ke email internal <nomor_hp>@yalt.test.
-- =====================================================================

-- ---------------------------------------------------------------------
-- View daftar pelanggan + jumlah pesanan (untuk tab Pelanggan admin)
-- ---------------------------------------------------------------------
create view public.customer_summary_view
with (security_invoker = true) as
select
  p.id,
  p.full_name,
  p.phone,
  p.created_at,
  count(o.id) as order_count,
  count(o.id) filter (where o.status <> 'diambil') as active_order_count
from public.profiles p
left join public.orders o on o.customer_id = p.id
where p.role = 'customer'
group by p.id;

revoke all on public.customer_summary_view from anon, authenticated;
grant select on public.customer_summary_view to authenticated;

-- ---------------------------------------------------------------------
-- Validasi input pelanggan (dipakai create & update)
-- ---------------------------------------------------------------------
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
  if p_phone is null or trim(p_phone) !~ '^08[0-9]{8,11}$' then
    raise exception 'Nomor HP harus diawali 08 dan berisi 10-13 angka' using errcode = '22023', hint = 'invalid_phone';
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: admin mendaftarkan pelanggan baru (akun login + profil)
-- ---------------------------------------------------------------------
create or replace function public.admin_create_customer(
  p_full_name text,
  p_phone text,
  p_password text default 'ayamgoreng'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := gen_random_uuid();
  v_name text := trim(p_full_name);
  v_phone text := trim(p_phone);
  v_email text;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat mendaftarkan pelanggan' using errcode = '42501';
  end if;

  perform public.fn_validate_customer_input(v_name, v_phone);
  if p_password is null or length(p_password) < 6 or p_password ~ '\s' then
    raise exception 'Password minimal 6 karakter tanpa spasi' using errcode = '22023', hint = 'invalid_password';
  end if;

  v_email := v_phone || '@yalt.test';
  if exists (select 1 from public.profiles where phone = v_phone)
     or exists (select 1 from auth.users where email = v_email) then
    raise exception 'Nomor HP sudah terdaftar' using errcode = '23505', hint = 'phone_taken';
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change_token_current,
    email_change, phone_change, phone_change_token, reauthentication_token
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    v_email, extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'), 'app_role', 'customer'),
    jsonb_build_object('full_name', v_name, 'phone', v_phone),
    now(), now(),
    '', '', '', '', '', '', '', ''
  );

  insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
  values (
    gen_random_uuid(), v_id, v_id::text, 'email',
    jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
    now(), now(), now()
  );

  -- profil dibuat oleh trigger on_auth_user_created
  return (
    select jsonb_build_object('id', p.id, 'full_name', p.full_name, 'phone', p.phone, 'role', p.role, 'order_count', 0)
    from public.profiles p where p.id = v_id
  );
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: admin mengubah nama / nomor HP pelanggan (email login ikut diperbarui)
-- ---------------------------------------------------------------------
create or replace function public.admin_update_customer(
  p_customer_id uuid,
  p_full_name text,
  p_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := trim(p_full_name);
  v_phone text := trim(p_phone);
  v_email text;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat mengubah data pelanggan' using errcode = '42501';
  end if;

  perform public.fn_validate_customer_input(v_name, v_phone);

  perform 1 from public.profiles where id = p_customer_id and role = 'customer' for update;
  if not found then
    raise exception 'Pelanggan tidak ditemukan' using errcode = 'PT404', hint = 'customer_not_found';
  end if;

  v_email := v_phone || '@yalt.test';
  if exists (select 1 from public.profiles where phone = v_phone and id <> p_customer_id)
     or exists (select 1 from auth.users where email = v_email and id <> p_customer_id) then
    raise exception 'Nomor HP sudah terdaftar' using errcode = '23505', hint = 'phone_taken';
  end if;

  update public.profiles set full_name = v_name, phone = v_phone where id = p_customer_id;

  update auth.users
  set email = v_email,
      raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
        || jsonb_build_object('full_name', v_name, 'phone', v_phone),
      updated_at = now()
  where id = p_customer_id;

  update auth.identities
  set identity_data = identity_data || jsonb_build_object('email', v_email),
      updated_at = now()
  where user_id = p_customer_id and provider = 'email';

  return (
    select jsonb_build_object(
      'id', c.id, 'full_name', c.full_name, 'phone', c.phone, 'role', 'customer', 'order_count', c.order_count
    )
    from public.customer_summary_view c where c.id = p_customer_id
  );
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: admin menghapus pelanggan. Ditolak jika sudah punya riwayat pesanan.
-- ---------------------------------------------------------------------
create or replace function public.admin_delete_customer(p_customer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menghapus pelanggan' using errcode = '42501';
  end if;

  perform 1 from public.profiles where id = p_customer_id and role = 'customer' for update;
  if not found then
    raise exception 'Pelanggan tidak ditemukan' using errcode = 'PT404', hint = 'customer_not_found';
  end if;

  if exists (select 1 from public.orders where customer_id = p_customer_id) then
    raise exception 'Pelanggan tidak bisa dihapus karena sudah memiliki riwayat pesanan'
      using errcode = 'PT409', hint = 'customer_has_orders';
  end if;

  -- profiles & identities ikut terhapus (on delete cascade)
  delete from auth.users where id = p_customer_id;

  return jsonb_build_object('id', p_customer_id, 'deleted', true);
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: hapus layanan. Jika sudah dipakai pesanan -> dinonaktifkan saja,
-- jika belum pernah dipakai -> dihapus permanen.
-- ---------------------------------------------------------------------
create or replace function public.sp_delete_service(p_service_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_service public.services;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menghapus layanan' using errcode = '42501';
  end if;

  select * into v_service from public.services where id = p_service_id for update;
  if not found then
    raise exception 'Layanan tidak ditemukan' using errcode = 'PT404', hint = 'service_not_found';
  end if;

  if exists (select 1 from public.order_items where service_id = p_service_id) then
    update public.services set is_active = false where id = p_service_id
    returning * into v_service;
    return jsonb_build_object('action', 'deactivated', 'service', to_jsonb(v_service));
  end if;

  delete from public.services where id = p_service_id;
  return jsonb_build_object('action', 'deleted', 'service', to_jsonb(v_service));
end;
$$;

revoke execute on function public.fn_validate_customer_input(text, text) from public, anon, authenticated;
revoke execute on function public.admin_create_customer(text, text, text) from public, anon;
revoke execute on function public.admin_update_customer(uuid, text, text) from public, anon;
revoke execute on function public.admin_delete_customer(uuid) from public, anon;
revoke execute on function public.sp_delete_service(uuid) from public, anon;

grant execute on function public.admin_create_customer(text, text, text) to authenticated;
grant execute on function public.admin_update_customer(uuid, text, text) to authenticated;
grant execute on function public.admin_delete_customer(uuid) to authenticated;
grant execute on function public.sp_delete_service(uuid) to authenticated;
