-- =====================================================================
-- Kesiapan rilis: hapus password awal default ('ayamgoreng') dari
-- admin_create_customer. Admin wajib mengisi password awal pelanggan,
-- sehingga tidak ada password bawaan yang tertulis di repo untuk akun baru.
-- PostgreSQL tidak mengizinkan menghapus default lewat CREATE OR REPLACE,
-- jadi fungsi di-drop lalu dibuat ulang (signature dan hak akses sama).
-- =====================================================================

drop function if exists public.admin_create_customer(text, text, text);

create or replace function public.admin_create_customer(
  p_full_name text,
  p_phone text,
  p_password text
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

revoke execute on function public.admin_create_customer(text, text, text) from public, anon;
grant execute on function public.admin_create_customer(text, text, text) to authenticated;
