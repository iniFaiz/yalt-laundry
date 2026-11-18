// password akun Supabase asli untuk tes integrasi, dibaca dari .env.test (tidak di-commit)
// sehingga password admin tidak tertulis di repo.
const adminPhone = '081111111111';
const adminPassword = String.fromEnvironment('ADMIN_PASSWORD');
const demoCustomerPassword = String.fromEnvironment('DEMO_CUSTOMER_PASSWORD', defaultValue: 'ayamgoreng');

String passwordFor(String phone) => phone == adminPhone ? adminPassword : demoCustomerPassword;
