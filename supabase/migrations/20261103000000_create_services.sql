-- Tabel layanan laundry beserta tarif per kg.
-- Layanan yang sudah dipakai pesanan dinonaktifkan (is_active = false), bukan dihapus.

create table public.services (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  price_per_kg numeric(12, 2) not null check (price_per_kg > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- nama layanan unik tanpa membedakan huruf besar/kecil
create unique index services_name_unique_idx on public.services (lower(name));
create index services_is_active_idx on public.services (is_active);

-- isi updated_at otomatis setiap baris diubah (dipakai ulang oleh tabel lain nanti)
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger services_set_updated_at
before update on public.services
for each row execute function public.set_updated_at();

-- RLS: daftar layanan & tarif adalah informasi publik, jadi boleh dibaca siapa saja.
-- Kebijakan tulis (insert/update/delete) khusus admin ditambahkan setelah tabel profiles dibuat.
alter table public.services enable row level security;

create policy "Layanan dapat dibaca semua pengguna"
on public.services
for select
to anon, authenticated
using (true);

grant select on public.services to anon, authenticated;
