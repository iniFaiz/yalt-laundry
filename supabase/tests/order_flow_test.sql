-- =====================================================================
-- Uji objek SQL YALT (tabel, RLS, fungsi, trigger, view, transaksi).
-- Jalankan seluruh isi file ini di Supabase SQL Editor setelah migration & seed.
--
-- Cara kerja:
-- - Peran pengguna disimulasikan dengan set_config('role') + request.jwt.claims,
--   sama seperti yang dilakukan PostgREST untuk setiap request API.
-- - Semua data tes dibatalkan (rollback) di akhir, database kembali seperti semula.
-- - Hasil akhir berupa tabel: no, test, hasil (LULUS/GAGAL), detail.
-- =====================================================================

create temp table if not exists yalt_test_results (no int, test text, passed boolean, detail text);
truncate yalt_test_results;

do $$
declare
  c_admin  constant uuid := '00000000-0000-4000-a000-000000000001';
  c_cust_a constant uuid := '00000000-0000-4000-a000-000000000002'; -- Prabowo
  c_cust_b constant uuid := '00000000-0000-4000-a000-000000000003'; -- Jokowi

  n text[] := '{}';     -- nama tes
  p boolean[] := '{}';  -- lulus?
  d text[] := '{}';     -- detail

  v_ok boolean;
  v_detail text;
  v_svc1 public.services;
  v_svc2 public.services;
  v_svc_x uuid;
  v_svc_y uuid;
  v_order jsonb;
  v_order_id uuid;
  v_order2_id uuid;
  v_token text;
  v_json jsonb;
  v_count int;
  v_count2 int;
  v_text text;
  v_expected numeric;
  v_new_customer uuid;
begin
  begin
    select * into v_svc1 from public.services where lower(name) = 'cuci kering';
    select * into v_svc2 from public.services where lower(name) = 'cuci kilat';
    -- layanan demo bisa saja dinonaktifkan admin, aktifkan dulu untuk keperluan tes
    update public.services set is_active = true where id in (v_svc1.id, v_svc2.id);

    -- 1 -------------------------------------------------------------
    n := n || 'fn_item_total(2.5 kg, Rp 6.000) = Rp 15.000'::text;
    p := p || (public.fn_item_total(2.5, 6000) = 15000);
    d := d || public.fn_item_total(2.5, 6000)::text;

    -- 2 Admin membuat pesanan 2 item (RPC atomik) ---------------------
    perform set_config('role', 'authenticated', true);
    perform set_config('request.jwt.claims', json_build_object('sub', c_admin, 'role', 'authenticated')::text, true);

    v_order := public.sp_create_order(
      c_cust_a,
      jsonb_build_array(
        jsonb_build_object('service_id', v_svc1.id, 'weight_kg', 2.5),
        jsonb_build_object('service_id', v_svc2.id, 'weight_kg', 1)
      ),
      'tes otomatis'
    );
    v_order_id := (v_order ->> 'id')::uuid;
    v_expected := public.fn_item_total(2.5, v_svc1.price_per_kg) + public.fn_item_total(1, v_svc2.price_per_kg);
    n := n || 'sp_create_order: total = jumlah subtotal, status diterima, token tidak bocor'::text;
    p := p || ((v_order ->> 'total_amount')::numeric = v_expected
               and v_order ->> 'status' = 'diterima'
               and not (v_order ? 'pickup_token'));
    d := d || format('%s total=%s harapan=%s', v_order ->> 'order_code', v_order ->> 'total_amount', v_expected);

    -- 3
    n := n || 'Estimasi selesai = dibuat + durasi layanan terlama'::text;
    p := p || ((v_order ->> 'estimated_completion_at')::timestamptz
               = (v_order ->> 'created_at')::timestamptz + make_interval(hours => greatest(v_svc1.duration_hours, v_svc2.duration_hours)));
    d := d || (v_order ->> 'estimated_completion_at');

    -- 4
    select count(*) into v_count from public.order_status_histories where order_id = v_order_id;
    select count(*) into v_count2 from public.order_items where order_id = v_order_id;
    n := n || 'Trigger mencatat riwayat awal (diterima) & 2 item tersimpan dengan snapshot tarif'::text;
    p := p || (v_count = 1 and v_count2 = 2);
    d := d || format('riwayat=%s item=%s', v_count, v_count2);

    -- 5 RLS pelanggan A ------------------------------------------------
    perform set_config('request.jwt.claims', json_build_object('sub', c_cust_a, 'role', 'authenticated')::text, true);
    select count(*) into v_count from public.orders where id = v_order_id;
    select count(*) into v_count2 from public.order_items where order_id = v_order_id;
    n := n || 'RLS: pelanggan A melihat pesanan & item miliknya'::text;
    p := p || (v_count = 1 and v_count2 = 2);
    d := d || format('orders=%s items=%s', v_count, v_count2);

    -- 6 RLS pelanggan B ------------------------------------------------
    perform set_config('request.jwt.claims', json_build_object('sub', c_cust_b, 'role', 'authenticated')::text, true);
    select count(*) into v_count from public.orders where id = v_order_id;
    select count(*) + (select count(*) from public.order_status_histories where order_id = v_order_id)
      into v_count2 from public.order_items where order_id = v_order_id;
    n := n || 'RLS: pelanggan B tidak bisa melihat pesanan/item/riwayat pelanggan A'::text;
    p := p || (v_count = 0 and v_count2 = 0);
    d := d || format('orders=%s items+riwayat=%s', v_count, v_count2);

    -- 7 kolom pickup_token tidak bisa dibaca langsung --------------------
    perform set_config('request.jwt.claims', json_build_object('sub', c_cust_a, 'role', 'authenticated')::text, true);
    begin
      execute 'select pickup_token from public.orders limit 1';
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = '42501'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Hak kolom: pickup_token tidak bisa di-SELECT langsung'::text;
    p := p || v_ok; d := d || v_detail;

    -- 8 pelanggan tidak boleh membuat pesanan ---------------------------
    begin
      perform public.sp_create_order(c_cust_a, jsonb_build_array(jsonb_build_object('service_id', v_svc1.id, 'weight_kg', 1)));
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = '42501'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Pelanggan memanggil sp_create_order ditolak (42501 / HTTP 403)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 9 pelanggan tidak boleh UPDATE langsung ---------------------------
    begin
      update public.orders set status = 'dicuci' where id = v_order_id;
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = '42501'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'UPDATE langsung ke tabel orders ditolak (42501)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 10 pelanggan mengambil token QR miliknya ---------------------------
    v_json := public.sp_get_pickup_token(v_order_id);
    v_token := v_json ->> 'pickup_token';
    n := n || 'sp_get_pickup_token: pemilik pesanan mendapat token acak 32 karakter'::text;
    p := p || (v_token ~ '^[0-9a-f]{32}$');
    d := d || coalesce(left(v_token, 6) || '...', 'null');

    -- 11 pelanggan B tidak bisa mengambil token milik A --------------------
    perform set_config('request.jwt.claims', json_build_object('sub', c_cust_b, 'role', 'authenticated')::text, true);
    begin
      perform public.sp_get_pickup_token(v_order_id);
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = 'PT404'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Pelanggan B meminta token pesanan A ditolak (PT404)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 12 transisi lompat ditolak -----------------------------------------
    perform set_config('request.jwt.claims', json_build_object('sub', c_admin, 'role', 'authenticated')::text, true);
    begin
      perform public.sp_update_order_status(v_order_id, 'siap_diambil');
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = 'PT409'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Transisi tidak valid diterima -> siap_diambil ditolak (PT409 / HTTP 409)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 13 diambil tidak boleh lewat sp_update_order_status ------------------
    begin
      perform public.sp_update_order_status(v_order_id, 'diambil');
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = 'PT409'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Status diambil lewat sp_update_order_status ditolak (wajib scan QR)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 14 QR sebelum siap diambil ditolak ------------------------------------
    begin
      perform public.sp_pickup_order(v_token);
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = 'PT409'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Scan QR saat status masih diterima ditolak (not_ready)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 15 alur valid ----------------------------------------------------------
    perform public.sp_update_order_status(v_order_id, 'dicuci');
    v_json := public.sp_update_order_status(v_order_id, 'siap_diambil');
    n := n || 'Transisi valid diterima -> dicuci -> siap_diambil berhasil'::text;
    p := p || (v_json ->> 'status' = 'siap_diambil');
    d := d || (v_json ->> 'status');

    -- 16 token salah ------------------------------------------------------------
    begin
      perform public.sp_pickup_order(replace(gen_random_uuid()::text, '-', ''));
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = 'PT404'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Scan QR dengan token tidak dikenal ditolak (PT404 / HTTP 404)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 17 pelanggan tidak boleh memproses pickup ----------------------------------
    perform set_config('request.jwt.claims', json_build_object('sub', c_cust_a, 'role', 'authenticated')::text, true);
    begin
      perform public.sp_pickup_order(v_token);
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = '42501'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Pelanggan memproses scan QR sendiri ditolak (42501)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 18 pickup berhasil ---------------------------------------------------------
    perform set_config('request.jwt.claims', json_build_object('sub', c_admin, 'role', 'authenticated')::text, true);
    v_json := public.sp_pickup_order(v_token);
    n := n || 'Admin scan QR valid: status diambil & token ditandai terpakai'::text;
    p := p || (v_json ->> 'status' = 'diambil' and v_json ->> 'pickup_token_used_at' is not null
               and (v_json ->> 'picked_up_by')::uuid = c_admin);
    d := d || format('status=%s used_at=%s', v_json ->> 'status', v_json ->> 'pickup_token_used_at');

    -- 19 QR dipakai ulang -----------------------------------------------------
    begin
      perform public.sp_pickup_order(v_token);
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = 'PT409'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'QR yang sudah dipakai ditolak (token_used / HTTP 409)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 20 riwayat lengkap ---------------------------------------------------------
    select string_agg(coalesce(from_status, '-') || '>' || to_status, ', ' order by id)
      into v_text from public.order_status_histories where order_id = v_order_id;
    n := n || 'Riwayat status tercatat otomatis oleh trigger (4 langkah)'::text;
    p := p || (v_text = '->diterima, diterima>dicuci, dicuci>siap_diambil, siap_diambil>diambil');
    d := d || v_text;

    -- 21 token tidak dikirim lagi setelah dipakai -------------------------------
    perform set_config('request.jwt.claims', json_build_object('sub', c_cust_a, 'role', 'authenticated')::text, true);
    v_json := public.sp_get_pickup_token(v_order_id);
    n := n || 'Token QR tidak dikirim lagi setelah dipakai'::text;
    p := p || (v_json ->> 'pickup_token' is null and v_json ->> 'pickup_token_used_at' is not null);
    d := d || v_json::text;

    -- 22 transaksi rollback: item kedua tidak valid ------------------------------
    perform set_config('request.jwt.claims', json_build_object('sub', c_admin, 'role', 'authenticated')::text, true);
    select count(*) into v_count from public.orders;
    select count(*) into v_count2 from public.order_items;
    begin
      perform public.sp_create_order(
        c_cust_a,
        jsonb_build_array(
          jsonb_build_object('service_id', v_svc1.id, 'weight_kg', 3),
          jsonb_build_object('service_id', v_svc1.id, 'weight_kg', -1)
        )
      );
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = '22023'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    v_ok := v_ok
      and v_count = (select count(*) from public.orders)
      and v_count2 = (select count(*) from public.order_items);
    n := n || 'Rollback: item ke-2 berat -1 -> pesanan & item pertama ikut batal'::text;
    p := p || v_ok;
    d := d || format('%s | orders %s->%s', v_detail, v_count, (select count(*) from public.orders));

    -- 23 transaksi rollback: layanan nonaktif ----------------------------------
    insert into public.services (name, price_per_kg, is_active)
    values ('Tes Nonaktif ' || gen_random_uuid(), 9000, false) returning id into v_svc_x;
    begin
      perform public.sp_create_order(
        c_cust_a,
        jsonb_build_array(
          jsonb_build_object('service_id', v_svc1.id, 'weight_kg', 1),
          jsonb_build_object('service_id', v_svc_x, 'weight_kg', 1)
        )
      );
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = '22023'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    v_ok := v_ok and v_count = (select count(*) from public.orders);
    n := n || 'Rollback: layanan nonaktif di item ke-2 -> seluruh pesanan batal'::text;
    p := p || v_ok; d := d || v_detail;

    -- 24 trigger menolak update langsung oleh pemilik database -------------------
    v_order := public.sp_create_order(c_cust_b, jsonb_build_array(jsonb_build_object('service_id', v_svc1.id, 'weight_kg', 4)));
    v_order2_id := (v_order ->> 'id')::uuid;
    perform set_config('role', 'none', true);
    begin
      update public.orders set status = 'siap_diambil' where id = v_order2_id;
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = 'PT409'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    begin
      update public.orders set status = 'dicuci' where id = v_order2_id;
      update public.orders set status = 'siap_diambil' where id = v_order2_id;
      update public.orders set status = 'diambil' where id = v_order2_id;
      v_ok := false; v_detail := v_detail || ' | diambil tanpa QR tidak ditolak';
    exception when others then
      v_ok := v_ok and sqlstate = 'PT409'; v_detail := v_detail || ' | ' || sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Trigger menolak lompat status & diambil tanpa QR walau update langsung (dashboard)'::text;
    p := p || v_ok; d := d || v_detail;
    perform set_config('role', 'authenticated', true);

    -- 25 view pesanan aktif ----------------------------------------------------
    select count(*) filter (where id = v_order2_id), count(*) filter (where id = v_order_id)
      into v_count, v_count2 from public.active_orders_view;
    n := n || 'active_orders_view memuat pesanan aktif dan tidak memuat pesanan yang sudah diambil'::text;
    p := p || (v_count = 1 and v_count2 = 0);
    d := d || format('aktif=%s selesai=%s', v_count, v_count2);

    -- 26 view laporan -----------------------------------------------------------
    select order_count into v_count from public.daily_order_report_view
    where order_date = (now() at time zone 'Asia/Jakarta')::date;
    n := n || 'daily_order_report_view menghitung pesanan hari ini (JOIN + agregat)'::text;
    p := p || (coalesce(v_count, 0) >= 2);
    d := d || format('order_count hari ini=%s', v_count);

    -- 27 view pelanggan & RLS ---------------------------------------------------
    select order_count into v_count from public.customer_summary_view where id = c_cust_a;
    perform set_config('request.jwt.claims', json_build_object('sub', c_cust_b, 'role', 'authenticated')::text, true);
    select count(*) into v_count2 from public.customer_summary_view;
    n := n || 'customer_summary_view: admin melihat jumlah pesanan, pelanggan hanya dirinya'::text;
    p := p || (v_count >= 1 and v_count2 = 1);
    d := d || format('order_count A=%s baris terlihat oleh B=%s', v_count, v_count2);

    -- 28 hapus layanan: dipakai -> nonaktif, tidak dipakai -> terhapus ----------
    perform set_config('request.jwt.claims', json_build_object('sub', c_admin, 'role', 'authenticated')::text, true);
    update public.services set is_active = true where id = v_svc_x;
    perform public.sp_create_order(c_cust_b, jsonb_build_array(jsonb_build_object('service_id', v_svc_x, 'weight_kg', 1)));
    insert into public.services (name, price_per_kg) values ('Tes Hapus ' || gen_random_uuid(), 9000) returning id into v_svc_y;
    v_json := public.sp_delete_service(v_svc_x);
    v_text := v_json ->> 'action';
    v_json := public.sp_delete_service(v_svc_y);
    n := n || 'sp_delete_service: layanan terpakai dinonaktifkan, tidak terpakai dihapus'::text;
    p := p || (v_text = 'deactivated' and v_json ->> 'action' = 'deleted'
               and exists (select 1 from public.services where id = v_svc_x and not is_active)
               and not exists (select 1 from public.services where id = v_svc_y));
    d := d || format('terpakai=%s tidak terpakai=%s', v_text, v_json ->> 'action');

    -- 29 FK menolak hapus fisik layanan terpakai ----------------------------------
    begin
      delete from public.services where id = v_svc_x;
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = '23503'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'DELETE langsung layanan yang dipakai pesanan ditolak FK (23503)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 30 kelola pelanggan -----------------------------------------------------------
    v_json := public.admin_create_customer('Pelanggan Tes', '089900001234', 'rahasia1');
    v_new_customer := (v_json ->> 'id')::uuid;
    begin
      perform public.admin_create_customer('Pelanggan Ganda', '089900001234');
      v_ok := false; v_detail := 'duplikat tidak ditolak';
    exception when others then
      v_ok := sqlstate = '23505'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    -- auth.users hanya bisa dibaca pemilik database, jadi pengecekan dilakukan tanpa role
    perform set_config('role', 'none', true);
    v_ok := v_ok and v_json ->> 'role' = 'customer'
      and exists (select 1 from auth.users where id = v_new_customer and email = '089900001234@yalt.test')
      and exists (select 1 from auth.identities where user_id = v_new_customer);
    perform set_config('role', 'authenticated', true);
    n := n || 'admin_create_customer membuat akun login + profil, nomor HP ganda ditolak (23505)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 31
    v_json := public.admin_update_customer(v_new_customer, 'Pelanggan Tes Ubah', '089900005678');
    perform set_config('role', 'none', true);
    v_ok := v_json ->> 'full_name' = 'Pelanggan Tes Ubah'
      and exists (select 1 from auth.users where id = v_new_customer and email = '089900005678@yalt.test');
    perform set_config('role', 'authenticated', true);
    n := n || 'admin_update_customer mengubah profil & email login'::text;
    p := p || v_ok; d := d || (v_json ->> 'phone');

    -- 32
    begin
      perform public.admin_delete_customer(c_cust_a);
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = 'PT409'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    perform public.admin_delete_customer(v_new_customer);
    v_ok := v_ok and not exists (select 1 from public.profiles where id = v_new_customer);
    n := n || 'admin_delete_customer: punya pesanan ditolak, tanpa pesanan terhapus'::text;
    p := p || v_ok; d := d || v_detail;

    -- 33
    perform set_config('request.jwt.claims', json_build_object('sub', c_cust_a, 'role', 'authenticated')::text, true);
    begin
      perform public.admin_create_customer('Penyusup', '089911112222');
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = '42501'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Pelanggan memanggil admin_create_customer ditolak (42501)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 34 pengguna anonim ----------------------------------------------------------
    perform set_config('role', 'anon', true);
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    begin
      perform 1 from public.orders limit 1;
      v_ok := false; v_detail := 'tidak ditolak';
    exception when others then
      v_ok := sqlstate = '42501'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Pengguna tanpa login tidak bisa membaca tabel orders (42501)'::text;
    p := p || v_ok; d := d || v_detail;

    -- 35 hardening: anon tetap bisa membaca katalog layanan, tetapi tidak bisa memanggil is_admin()
    select count(*) into v_count from public.services;
    begin
      perform public.is_admin();
      v_ok := false; v_detail := 'is_admin() tidak ditolak';
    exception when others then
      v_ok := sqlstate = '42501'; v_detail := sqlstate || ' ' || sqlerrm;
    end;
    n := n || 'Hardening: anon membaca layanan, is_admin() ditolak (42501)'::text;
    p := p || (v_ok and v_count > 0); d := d || format('layanan=%s | %s', v_count, v_detail);

    -- batalkan semua data tes
    raise exception using errcode = 'P0099', message = 'rollback_test_data';
  exception when others then
    if sqlstate <> 'P0099' then
      n := n || 'ERROR TAK TERDUGA (tes berhenti di sini)'::text;
      p := p || false;
      d := d || (sqlstate || ': ' || sqlerrm);
    end if;
  end;

  insert into yalt_test_results
  select i, n[i], p[i], d[i] from generate_subscripts(n, 1) as i;
end;
$$;

select
  no,
  test,
  case when passed then 'LULUS' else 'GAGAL' end as hasil,
  detail
from yalt_test_results
order by no;
