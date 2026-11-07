-- =====================================================================
-- Hardening keamanan berdasarkan Supabase Security Advisor (7 Nov 2026).
-- =====================================================================

-- 1. Function Search Path Mutable: kunci search_path agar fungsi tidak bisa
--    "dibajak" oleh objek dengan nama sama di skema lain.
alter function public.set_updated_at() set search_path = '';
alter function public.fn_item_total(numeric, numeric) set search_path = '';

-- 2. handle_new_user() hanya untuk trigger on_auth_user_created.
--    Trigger tetap berjalan tanpa hak EXECUTE (hak hanya dicek saat CREATE TRIGGER).
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- 3. is_admin() tidak perlu bisa dipanggil tanpa login.
--    authenticated tetap butuh EXECUTE karena dipakai di kebijakan RLS & RPC.
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
