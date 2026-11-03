-- Data awal layanan laundry (sama dengan data dummy di aplikasi)
insert into public.services (name, price_per_kg, is_active) values
  ('Cuci Kering', 6000, true),
  ('Cuci Setrika', 8000, true),
  ('Setrika Saja', 5000, true),
  ('Cuci Kilat', 12000, true)
on conflict do nothing;

-- Akun demo Supabase Auth. Login di aplikasi memakai nomor HP + password;
-- aplikasi mengubah nomor HP menjadi email internal <nomor_hp>@yalt.test.
-- Password semua akun demo: ayamgoreng
-- Profil (nama, nomor HP, role) dibuat otomatis oleh trigger on_auth_user_created.
with demo_users (id, phone, full_name, app_role) as (
  values
    ('00000000-0000-4000-a000-000000000001'::uuid, '081111111111', 'Admin YALT', 'admin'),
    ('00000000-0000-4000-a000-000000000002'::uuid, '081234567890', 'Prabowo', 'customer'),
    ('00000000-0000-4000-a000-000000000003'::uuid, '089876543210', 'Jokowi', 'customer')
)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change_token_current,
  email_change, phone_change, phone_change_token, reauthentication_token
)
select
  '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated',
  phone || '@yalt.test', extensions.crypt('ayamgoreng', extensions.gen_salt('bf')), now(),
  jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'), 'app_role', app_role),
  jsonb_build_object('full_name', full_name, 'phone', phone),
  now(), now(),
  '', '', '', '', '', '', '', ''
from demo_users
on conflict (id) do nothing;

-- identitas login email untuk akun demo (dibutuhkan Supabase Auth saat sign in)
insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select
  gen_random_uuid(), u.id, u.id::text, 'email',
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  now(), now(), now()
from auth.users u
where u.email like '%@yalt.test'
on conflict (provider_id, provider) do nothing;
