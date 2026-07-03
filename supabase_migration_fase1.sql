-- ═══════════════════════════════════════════════════════════════════════
-- SQL MIGRATION — Galaxi Gadai (jalankan di Supabase SQL Editor)
-- Aman dijalankan berulang kali (idempotent)
-- ═══════════════════════════════════════════════════════════════════════

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ════════════════════════════════════════════════════════════════
-- 0. TABEL BRANCHES (shared dengan Servis HP)
--    Lewati jika sudah ada dari project servishp3
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS branches (
  id       VARCHAR(50)  PRIMARY KEY,
  name     VARCHAR(100) NOT NULL,
  location VARCHAR(255) NOT NULL DEFAULT '',
  password VARCHAR(50)  DEFAULT '1234'
);

-- Seed minimal cabang untuk gadai (idempotent)
INSERT INTO branches (id, name, location) VALUES
  ('all', 'Semua Cabang',      'Seluruh Indonesia'),
  ('jkt', 'Galaxi Jakarta',    'Jakarta Barat'),
  ('bdg', 'Galaxi Bandung',    'Dago'),
  ('sby', 'Galaxi Surabaya',   'Gubeng'),
  ('mdn', 'Galaxi Medan',      'Petisah'),
  ('mks', 'Galaxi Makassar',   'Panakkukang'),
  ('ygy', 'Galaxi Yogyakarta', 'Sleman')
ON CONFLICT (id) DO UPDATE SET
  name     = EXCLUDED.name,
  location = EXCLUDED.location;


-- ════════════════════════════════════════════════════════════════
-- 1. TABEL PROFILES (shared dengan Servis HP)
--    Staff login menggunakan Supabase Auth + tabel ini
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS profiles (
  id         UUID         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username   TEXT         NOT NULL,
  full_name  TEXT         NOT NULL DEFAULT '',
  email      TEXT         NOT NULL DEFAULT '',
  role       TEXT         NOT NULL DEFAULT 'teknisi'
                            CHECK (role IN ('superadmin', 'admin', 'teknisi', 'verifikator')),
  branch_id  VARCHAR(50)  REFERENCES branches(id) ON DELETE SET NULL,
  is_active  BOOLEAN      NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ  DEFAULT NOW()
);

-- Tambahkan kolom yang mungkin belum ada di project lama
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email     TEXT    NOT NULL DEFAULT '';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Index untuk pencarian profil
CREATE INDEX IF NOT EXISTS idx_profiles_username  ON profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_branch_id ON profiles(branch_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role      ON profiles(role);

-- RLS profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles: user dapat membaca data sendiri"      ON profiles;
DROP POLICY IF EXISTS "Profiles: superadmin dapat membaca semua"       ON profiles;
DROP POLICY IF EXISTS "Profiles: allow anon read for login lookup"     ON profiles;

-- User bisa membaca profil dirinya sendiri (setelah login)
CREATE POLICY "Profiles: user dapat membaca data sendiri" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Anon boleh baca kolom email & username untuk keperluan resolusi username → email saat login
-- (dipakai oleh loginStaff() sebelum Supabase Auth signIn)
CREATE POLICY "Profiles: allow anon read for login lookup" ON profiles
  FOR SELECT USING (true);

-- Semua authenticated user bisa update profile sendiri
DROP POLICY IF EXISTS "Profiles: user dapat update data sendiri" ON profiles;
CREATE POLICY "Profiles: user dapat update data sendiri" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Service role bisa insert/update semua (untuk admin create staff)
DROP POLICY IF EXISTS "Profiles: authenticated all access" ON profiles;
CREATE POLICY "Profiles: authenticated all access" ON profiles
  FOR ALL USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 2. TABEL NASABAH (data peminjam/penggadai)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_nasabah (
  id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id  VARCHAR(50)  NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  name       TEXT         NOT NULL,
  nik        TEXT         NOT NULL DEFAULT '',
  phone      TEXT         NOT NULL DEFAULT '',
  address    TEXT         NOT NULL DEFAULT '',
  birth_place TEXT        DEFAULT '',
  birth_date  TEXT        DEFAULT '',
  gender     TEXT         NOT NULL DEFAULT 'Laki-laki'
                            CHECK (gender IN ('Laki-laki', 'Perempuan')),
  created_at TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gadai_nasabah_branch    ON gadai_nasabah(branch_id);
CREATE INDEX IF NOT EXISTS idx_gadai_nasabah_phone     ON gadai_nasabah(phone);
CREATE INDEX IF NOT EXISTS idx_gadai_nasabah_nik       ON gadai_nasabah(nik);
CREATE INDEX IF NOT EXISTS idx_gadai_nasabah_created   ON gadai_nasabah(created_at DESC);

-- RLS gadai_nasabah
ALTER TABLE gadai_nasabah ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Nasabah: staff authenticated full access" ON gadai_nasabah;
CREATE POLICY "Nasabah: staff authenticated full access" ON gadai_nasabah
  FOR ALL USING (auth.role() = 'authenticated');

-- Nasabah bisa membaca data dirinya sendiri melalui join dengan nasabah_accounts
-- (menggunakan anon key — nasabah tidak punya Supabase Auth session)
DROP POLICY IF EXISTS "Nasabah: anon read for customer portal" ON gadai_nasabah;
CREATE POLICY "Nasabah: anon read for customer portal" ON gadai_nasabah
  FOR SELECT USING (true);


-- ════════════════════════════════════════════════════════════════
-- 3. TABEL AKUN NASABAH (autentikasi custom, bukan Supabase Auth)
--    Password disimpan sebagai SHA-256 hash
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_nasabah_accounts (
  id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nasabah_id UUID         NOT NULL REFERENCES gadai_nasabah(id) ON DELETE CASCADE,
  phone      TEXT         NOT NULL UNIQUE,
  password   TEXT         NOT NULL,   -- SHA-256 hex string
  created_at TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gadai_nasabah_accounts_phone ON gadai_nasabah_accounts(phone);

-- RLS gadai_nasabah_accounts
ALTER TABLE gadai_nasabah_accounts ENABLE ROW LEVEL SECURITY;

-- Anon boleh SELECT untuk validasi login (phone + password hash)
DROP POLICY IF EXISTS "NasabahAcc: anon select for login" ON gadai_nasabah_accounts;
CREATE POLICY "NasabahAcc: anon select for login" ON gadai_nasabah_accounts
  FOR SELECT USING (true);

-- Anon boleh INSERT untuk registrasi
DROP POLICY IF EXISTS "NasabahAcc: anon insert for register" ON gadai_nasabah_accounts;
CREATE POLICY "NasabahAcc: anon insert for register" ON gadai_nasabah_accounts
  FOR INSERT WITH CHECK (true);

-- Anon boleh UPDATE untuk ganti password
DROP POLICY IF EXISTS "NasabahAcc: anon update for password change" ON gadai_nasabah_accounts;
CREATE POLICY "NasabahAcc: anon update for password change" ON gadai_nasabah_accounts
  FOR UPDATE USING (true);

-- Staff authenticated bisa full access (admin reset password, dll)
DROP POLICY IF EXISTS "NasabahAcc: staff full access" ON gadai_nasabah_accounts;
CREATE POLICY "NasabahAcc: staff full access" ON gadai_nasabah_accounts
  FOR ALL USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 4. TABEL TRANSAKSI GADAI
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_transactions (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nasabah_id       UUID         NOT NULL REFERENCES gadai_nasabah(id) ON DELETE RESTRICT,
  branch_id        VARCHAR(50)  NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  collateral_type  TEXT         NOT NULL,           -- 'Smartphone', 'Laptop', 'Emas', 'Jam', dll
  brand            TEXT         NOT NULL DEFAULT '',
  model            TEXT         NOT NULL DEFAULT '',
  condition        TEXT         NOT NULL DEFAULT '',
  principal        BIGINT       NOT NULL DEFAULT 0,  -- Pokok pinjaman (Rp)
  period_days      INT          NOT NULL DEFAULT 15, -- Tenor (hari)
  daily_fee        BIGINT       NOT NULL DEFAULT 0,  -- Biaya harian (Rp)
  total_fee        BIGINT       NOT NULL DEFAULT 0,  -- Total biaya titip (daily_fee × period_days)
  total_repayment  BIGINT       NOT NULL DEFAULT 0,  -- Total yang harus dibayar (principal + total_fee)
  date_applied     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  date_due         TIMESTAMPTZ  NOT NULL,
  status           TEXT         NOT NULL DEFAULT 'Aktif'
                     CHECK (status IN ('Aktif', 'Macet', 'Lunas', 'Lelang')),
  created_at       TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gadai_tx_nasabah    ON gadai_transactions(nasabah_id);
CREATE INDEX IF NOT EXISTS idx_gadai_tx_branch     ON gadai_transactions(branch_id);
CREATE INDEX IF NOT EXISTS idx_gadai_tx_status     ON gadai_transactions(status);
CREATE INDEX IF NOT EXISTS idx_gadai_tx_date_due   ON gadai_transactions(date_due);
CREATE INDEX IF NOT EXISTS idx_gadai_tx_created    ON gadai_transactions(created_at DESC);

-- RLS gadai_transactions
ALTER TABLE gadai_transactions ENABLE ROW LEVEL SECURITY;

-- Staff (authenticated) full access
DROP POLICY IF EXISTS "GadaiTx: staff full access" ON gadai_transactions;
CREATE POLICY "GadaiTx: staff full access" ON gadai_transactions
  FOR ALL USING (auth.role() = 'authenticated');

-- Nasabah (anon) bisa baca transaksi miliknya (portal nasabah)
DROP POLICY IF EXISTS "GadaiTx: anon read for nasabah portal" ON gadai_transactions;
CREATE POLICY "GadaiTx: anon read for nasabah portal" ON gadai_transactions
  FOR SELECT USING (true);


-- ════════════════════════════════════════════════════════════════
-- 5. TABEL RIWAYAT PERPANJANGAN TENOR
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_extension_history (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id   UUID         NOT NULL REFERENCES gadai_transactions(id) ON DELETE CASCADE,
  jatip_dibayar    BIGINT       NOT NULL DEFAULT 0,  -- Jasa titip yang dibayar saat perpanjangan
  tgl_perpanjangan TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  tgl_tempo_lama   TIMESTAMPTZ  NOT NULL,
  tgl_tempo_baru   TIMESTAMPTZ  NOT NULL,
  payment_method   TEXT         NOT NULL DEFAULT '',
  created_at       TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gadai_ext_tx_id  ON gadai_extension_history(transaction_id);
CREATE INDEX IF NOT EXISTS idx_gadai_ext_created ON gadai_extension_history(created_at DESC);

-- RLS gadai_extension_history
ALTER TABLE gadai_extension_history ENABLE ROW LEVEL SECURITY;

-- Staff full access
DROP POLICY IF EXISTS "GadaiExt: staff full access" ON gadai_extension_history;
CREATE POLICY "GadaiExt: staff full access" ON gadai_extension_history
  FOR ALL USING (auth.role() = 'authenticated');

-- Nasabah (anon) bisa read perpanjangan transaksinya
DROP POLICY IF EXISTS "GadaiExt: anon read" ON gadai_extension_history;
CREATE POLICY "GadaiExt: anon read" ON gadai_extension_history
  FOR SELECT USING (true);

-- Nasabah (anon) bisa insert untuk perpanjangan mandiri dari portal
DROP POLICY IF EXISTS "GadaiExt: anon insert" ON gadai_extension_history;
CREATE POLICY "GadaiExt: anon insert" ON gadai_extension_history
  FOR INSERT WITH CHECK (true);


-- ════════════════════════════════════════════════════════════════
-- 6. TABEL KONFIGURASI SISTEM (key-value store)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_config (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Isi nilai default konfigurasi
INSERT INTO gadai_config (key, value) VALUES
  ('tariff_per_unit', '5000'),
  ('unit_amount',     '500000'),
  ('min_tenor',       '15'),
  ('max_tenor',       '30'),
  ('alert_days',      '3')
ON CONFLICT (key) DO NOTHING;

-- RLS gadai_config
ALTER TABLE gadai_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all authenticated users" ON gadai_config;
CREATE POLICY "Allow all authenticated users" ON gadai_config
  FOR ALL USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 7. TABEL WALLET TENANT (saldo per cabang)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_wallet (
  branch_id  VARCHAR(50) PRIMARY KEY REFERENCES branches(id) ON DELETE CASCADE,
  balance    BIGINT      NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE gadai_wallet ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated" ON gadai_wallet;
CREATE POLICY "Allow authenticated" ON gadai_wallet
  FOR ALL USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 8. TABEL RIWAYAT MUTASI WALLET
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_wallet_mutations (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id   VARCHAR(50) NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  type        TEXT        NOT NULL CHECK (type IN ('Kredit', 'Debet')),
  amount      BIGINT      NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE gadai_wallet_mutations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated" ON gadai_wallet_mutations;
CREATE POLICY "Allow authenticated" ON gadai_wallet_mutations
  FOR ALL USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 9. FUNCTION: Top Up Wallet (atomic increment)
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION gadai_wallet_topup(p_branch_id TEXT, p_amount BIGINT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO gadai_wallet (branch_id, balance)
  VALUES (p_branch_id, p_amount)
  ON CONFLICT (branch_id)
  DO UPDATE SET balance    = gadai_wallet.balance + p_amount,
                updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ════════════════════════════════════════════════════════════════
-- 10. TABEL LOG AKTIVITAS
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_activity_logs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     TEXT        NOT NULL,
  role        TEXT        NOT NULL DEFAULT 'nasabah',
  action      TEXT        NOT NULL,
  description TEXT,
  metadata    JSONB,
  ip_address  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id    ON gadai_activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON gadai_activity_logs(created_at DESC);

ALTER TABLE gadai_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated read/insert" ON gadai_activity_logs;
DROP POLICY IF EXISTS "Allow insert activity log"       ON gadai_activity_logs;
DROP POLICY IF EXISTS "Allow read activity log"         ON gadai_activity_logs;

-- INSERT boleh siapa saja (anon & authenticated) — nasabah tidak punya Supabase session
CREATE POLICY "Allow insert activity log" ON gadai_activity_logs
  FOR INSERT WITH CHECK (true);

-- SELECT hanya staff (authenticated)
CREATE POLICY "Allow read activity log" ON gadai_activity_logs
  FOR SELECT USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 11. FUNCTION: Auto-mark transaksi Aktif yg sudah jatuh tempo → Macet
--     Bisa dipanggil manual atau via pg_cron (opsional)
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION gadai_mark_overdue()
RETURNS INT AS $$
DECLARE
  affected INT;
BEGIN
  UPDATE gadai_transactions
  SET    status = 'Macet'
  WHERE  status = 'Aktif'
    AND  date_due < NOW();
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ════════════════════════════════════════════════════════════════
-- SELESAI
-- Urutan eksekusi yang benar:
--   0. branches
--   1. profiles (pastikan kolom email & is_active sudah ada)
--   2. gadai_nasabah
--   3. gadai_nasabah_accounts
--   4. gadai_transactions
--   5. gadai_extension_history
--   6. gadai_config
--   7. gadai_wallet
--   8. gadai_wallet_mutations
--   9. gadai_wallet_topup (function)
--  10. gadai_activity_logs
--  11. gadai_mark_overdue (function)
-- ════════════════════════════════════════════════════════════════
