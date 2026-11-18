// Menjalankan seluruh koleksi Bruno dengan URL & key dari ../.env
// Pemakaian (dari root project):  node bruno/run-tests.mjs
// Laporan disimpan ke docs/evidence/bruno-report.(json|html)
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');

const env = Object.fromEntries(
  fs.readFileSync(path.join(root, '.env'), 'utf8')
    .split(/\r?\n/)
    .filter((line) => /^[A-Z_]+=/.test(line))
    .map((line) => [line.slice(0, line.indexOf('=')), line.slice(line.indexOf('=') + 1).trim()]),
);

// password admin disimpan terpisah di ../.env.test agar tidak ikut di-build ke aplikasi
const envTestFile = path.join(root, '.env.test');
if (fs.existsSync(envTestFile)) {
  for (const line of fs.readFileSync(envTestFile, 'utf8').split(/\r?\n/)) {
    if (/^[A-Z_]+=/.test(line)) env[line.slice(0, line.indexOf('='))] = line.slice(line.indexOf('=') + 1).trim();
  }
}

if (!env.ADMIN_PASSWORD) {
  console.error('ADMIN_PASSWORD belum diisi di .env.test (salin dari .env.test.example)');
  process.exit(1);
}

if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) {
  console.error('SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY belum diisi di .env');
  process.exit(1);
}

const evidence = path.join(root, 'docs', 'evidence');
fs.mkdirSync(evidence, { recursive: true });

const result = spawnSync(
  'npx',
  [
    '--yes', '@usebruno/cli@4.3.0', 'run', '-r',
    '--env', 'Supabase',
    '--env-var', `base_url=${env.SUPABASE_URL}`,
    '--env-var', `publishable_key=${env.SUPABASE_PUBLISHABLE_KEY}`,
    '--env-var', `admin_password=${env.ADMIN_PASSWORD}`,
    '--reporter-json', path.join(evidence, 'bruno-report.json'),
    '--reporter-html', path.join(evidence, 'bruno-report.html'),
  ],
  { cwd: here, stdio: 'inherit', shell: process.platform === 'win32' },
);

// sensor token login & key sebelum laporan disimpan sebagai bukti
export function redact(text, secrets = []) {
  let out = text
    .replace(/eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[REDACTED_JWT]')
    .replace(/("refresh_token"\s*:\s*")[^"]+"/g, '$1[REDACTED]"')
    .replace(/(\\"refresh_token\\"\s*:\s*\\")[^"\\]+/g, '$1[REDACTED]');
  for (const secret of secrets) out = out.split(secret).join('[REDACTED_KEY]');
  // laporan HTML menyimpan hasil sebagai base64 (UTF-8): decode, sensor, encode ulang
  return out.replace(/decodeBase64\('([A-Za-z0-9+/=]+)'\)/g, (_, b64) => {
    const clean = redact(Buffer.from(b64, 'base64').toString('utf8'), secrets);
    return `decodeBase64('${Buffer.from(clean, 'utf8').toString('base64')}')`;
  });
}

for (const file of ['bruno-report.json', 'bruno-report.html']) {
  const target = path.join(evidence, file);
  if (fs.existsSync(target)) {
    fs.writeFileSync(target, redact(fs.readFileSync(target, 'utf8'), [env.SUPABASE_PUBLISHABLE_KEY, env.ADMIN_PASSWORD]));
  }
}
process.exit(result.status ?? 1);
