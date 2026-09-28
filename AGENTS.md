# YALT — Yet Another Laundry Tracking

Build a Flutter Android application for tracking laundry orders as a Mobile Application Development course project, prepared for release on the Google Play Store. Prioritize straightforward implementation, polished UI, and features that are easy to demonstrate. Initial scope: one laundry outlet, one application, and admin and customer roles.

## Technology and workflow

- Use Flutter with Material 3 for the mobile application, Supabase (PostgreSQL, Supabase Auth, Row Level Security, Database Functions) for the cloud backend, and Bruno for API testing.
- Use Supabase Auth for authentication. Enforce authorization and access control in the backend using PostgreSQL Row Level Security (RLS) policies and security-definer functions. Customers may access only their own orders; service management and status updates are restricted to admins.
- Project structure: Flutter app (`lib/`, `android/`), `supabase/` (migrations and seed scripts), `bruno/` (API collections), and `docs/`. Manage all SQL objects (tables, RLS, functions, triggers, views) via Supabase migrations.
- Separate UI, state, and Supabase client access cleanly. Prefer direct implementations with only necessary dependencies (`supabase_flutter`, etc.).
- Make routine technical decisions independently and document important assumptions. Use Indonesian for the application UI, project documentation, and explanations to the user. Keep this AGENTS.md in English.

## MVP features

- Implement login and logout; provide demo admin and customer accounts through Supabase seed data.
- Admins manage customers, services, prices per kilogram, and orders with service and weight details.
- Customers view active orders, total charges, estimated completion times, status timelines, and order history.
- Status flow: Received (`diterima`) → Washing (`dicuci`) → Ready for pickup (`siap_diambil`) → Collected (`diambil`). Validate transitions strictly in the database/backend.
- Standout features: an animated timeline, a digital receipt summary, and a pickup QR code scanned by an admin.
- QR codes use random, single-use tokens. The `diambil` status is reachable only through the QR pickup process from `siap_diambil`; validate and mark the token as used atomically with row locking in the backend.

## API & Backend Integration

- Flutter application interacts with Supabase using the `supabase_flutter` SDK and PostgREST endpoints / Database RPCs.
- Maintain RESTful accessibility: Supabase PostgREST endpoints and RPC functions can be tested via Bruno (e.g., `GET /rest/v1/services`, `POST /rest/v1/rpc/sp_update_order_status`).
- Deactivate services already referenced by orders (`is_active = false`). Allow physical deletion only for unreferenced services; preserve order history.
- Use consistent JSON responses and appropriate HTTP status codes. Validate input, authorization, pricing, and status on the backend.
- Configure Supabase URL and anon/publishable keys via environment configuration (`.env` / Flutter environment config); provide an `.env.example` without secrets.

## Database (PostgreSQL on Supabase)

- Core tables: `profiles` (linked to `auth.users`), `services`, `orders`, `order_items`, and `order_status_histories`. Include an ERD, foreign keys, constraints, and indexes appropriate to the queries.
- Store a price snapshot in each order item (`price_per_kg_snapshot`) so later price changes do not affect existing order totals. Use `DECIMAL`/`NUMERIC` for weight and monetary values.
- Stored function / procedure `sp_update_order_status`: validate and update order status; must be callable from the application or API.
- Stored function `fn_item_total`: calculate a subtotal from weight and price; use it in order calculations.
- Trigger: record status changes automatically in `order_status_histories` on insert/update.
- View: `active_orders_view` summarizing active orders. Use JOINs and aggregates for simple reports.
- Transaction / Atomicity: save an order and all its items as one atomic operation (via an atomic PostgreSQL RPC function); roll back all changes on failure.
- Protect QR pickup against concurrent requests with row locking (`SELECT ... FOR UPDATE`) inside an atomic function.
- Document evidence for each database feature in `docs/database.md` (tables, RLS policies, functions, triggers, views, transactions, and backup/restore).

## UI/UX

- Use a blue/teal palette, clear order cards, status labels, Indonesian rupiah formatting, and simple navigation appropriate to each role.
- Handle loading, empty, error, form validation, and success states. Communicate status with text as well as color.
- Reload status when the page opens and when the user refreshes it (or leverage Supabase Realtime subscriptions where suitable).

## Evidence and completion criteria

- Create a Bruno collection covering authentication, CRUD operations, RPC calls, and RLS checks, with assertions for status codes and response bodies.
- Test attempts to access another customer's orders (RLS verification), invalid status transitions, QR reuse, and transactional rollback when saving an order item fails. Verify the resulting database state.
- Run Flutter analysis and test SQL objects against PostgreSQL on Supabase.
- Complete demo flow: admin creates an order → customer views the timeline → admin updates status → admin scans the QR code → order is completed.
- Save Bruno evidence, Flutter recordings/screenshots, and Supabase logs linked by the same order ID. Report actual test results and unresolved limitations.
- Include a README explaining how to run the application, Supabase configuration/migrations/seeders, Android build & Play Store readiness, and Bruno tests.
