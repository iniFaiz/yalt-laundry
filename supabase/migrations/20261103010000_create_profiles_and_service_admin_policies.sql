-- Profil pengguna (terhubung ke auth.users) beserta role admin/pelanggan,
-- lalu kebijakan RLS agar hanya admin yang boleh mengelola layanan.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null check (length(trim(full_name)) >= 3),
  phone text not null unique check (phone ~ '^08[0-9]{8,11}$'),
  role text not null default 'customer' check (role in ('admin', 'customer')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_role_idx on public.profiles (role);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- Buat profil otomatis setiap akun baru dibuat di Supabase Auth.
-- Nama & nomor HP diambil dari user metadata, sedangkan role diambil dari app metadata
-- (app metadata hanya bisa diisi server/admin, jadi pengguna tidak bisa mengangkat dirinya jadi admin).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
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

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Cek apakah pengguna yang sedang login adalah admin.
-- security definer agar bisa membaca profiles tanpa terhalang RLS (mencegah rekursi kebijakan).
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- RLS profiles: pengguna hanya melihat profilnya sendiri, admin melihat semua.
alter table public.profiles enable row level security;

create policy "Pengguna melihat profil sendiri, admin melihat semua"
on public.profiles
for select
to authenticated
using (id = auth.uid() or public.is_admin());

grant select on public.profiles to authenticated;

-- RLS services: tambah, ubah, hapus hanya untuk admin.
create policy "Admin dapat menambah layanan"
on public.services
for insert
to authenticated
with check (public.is_admin());

create policy "Admin dapat mengubah layanan"
on public.services
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admin dapat menghapus layanan"
on public.services
for delete
to authenticated
using (public.is_admin());

grant insert, update, delete on public.services to authenticated;
