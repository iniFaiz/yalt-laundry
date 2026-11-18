-- =====================================================================
-- Kesiapan rilis: tolak pendaftaran publik (POST /auth/v1/signup).
-- Akun sah selalu dibuat oleh admin_create_customer atau seed, dan keduanya
-- mengisi raw_app_meta_data.app_role. Pengguna tidak bisa mengisi app_metadata
-- lewat signup, jadi akun tanpa app_role pasti berasal dari pendaftaran publik.
-- Tanpa ini, siapa pun bisa "memesan" nomor HP pelanggan lewat API
-- (profil dibuat trigger) sehingga admin tidak bisa mendaftarkannya.
-- Tetap matikan juga "Allow new users to sign up" di dashboard Supabase.
-- =====================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.raw_app_meta_data ->> 'app_role', '') not in ('admin', 'customer') then
    raise exception 'Pendaftaran mandiri tidak diizinkan. Akun dibuat oleh admin outlet.'
      using errcode = '42501', hint = 'signup_disabled';
  end if;

  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    case when new.raw_app_meta_data ->> 'app_role' = 'admin' then 'admin' else 'customer' end
  );
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
