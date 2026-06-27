-- ═══════════════════════════════════════════════════════════════
-- SQL MIGRATION — Galaxi Gadai (jalankan di Supabase SQL Editor)
-- Aman dijalankan berulang kali (idempotent)
-- ═══════════════════════════════════════════════════════════════

-- 1. TABEL KONFIGURASI SISTEM (key-value store)
CREATE TABLE IF NOT EXISTS gadai_config (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Isi nilai default konfigurasi
INSERT INTO gadai_config (key, value) VALUES
  ('tariff_per_unit', '5000'),
  ('unit_amount', '500000'),
  ('min_tenor', '15'),
  ('max_tenor', '30'),
  ('alert_days', '3')
ON CONFLICT (key) DO NOTHING;

-- RLS gadai_config
ALTER TABLE gadai_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all authenticated users" ON gadai_config;
CREATE POLICY "Allow all authenticated users" ON gadai_config
  FOR ALL USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 2. TABEL WALLET TENANT (saldo per cabang)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_wallet (
  branch_id  TEXT PRIMARY KEY REFERENCES branches(id) ON DELETE CASCADE,
  balance    BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE gadai_wallet ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated" ON gadai_wallet;
CREATE POLICY "Allow authenticated" ON gadai_wallet
  FOR ALL USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 3. TABEL RIWAYAT MUTASI WALLET
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_wallet_mutations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id   TEXT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  type        TEXT NOT NULL CHECK (type IN ('Kredit', 'Debet')),
  amount      BIGINT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE gadai_wallet_mutations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated" ON gadai_wallet_mutations;
CREATE POLICY "Allow authenticated" ON gadai_wallet_mutations
  FOR ALL USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 4. FUNCTION: Top Up Wallet (atomic increment)
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION gadai_wallet_topup(p_branch_id TEXT, p_amount BIGINT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO gadai_wallet (branch_id, balance)
  VALUES (p_branch_id, p_amount)
  ON CONFLICT (branch_id)
  DO UPDATE SET balance     = gadai_wallet.balance + p_amount,
                updated_at  = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ════════════════════════════════════════════════════════════════
-- 5. TABEL LOG AKTIVITAS NASABAH
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS gadai_activity_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'nasabah',
  action      TEXT NOT NULL,
  description TEXT,
  metadata    JSONB,
  ip_address  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Index agar query per user atau per waktu cepat
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id   ON gadai_activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON gadai_activity_logs(created_at DESC);

ALTER TABLE gadai_activity_logs ENABLE ROW LEVEL SECURITY;

-- INSERT: Boleh oleh siapa saja (anon & authenticated) karena nasabah
-- menggunakan custom auth, bukan Supabase Auth session.
DROP POLICY IF EXISTS "Allow authenticated read/insert" ON gadai_activity_logs;
DROP POLICY IF EXISTS "Allow insert activity log" ON gadai_activity_logs;
DROP POLICY IF EXISTS "Allow read activity log" ON gadai_activity_logs;

CREATE POLICY "Allow insert activity log" ON gadai_activity_logs
  FOR INSERT WITH CHECK (true);

-- SELECT: Hanya staff yang login via Supabase Auth (admin, super_admin)
CREATE POLICY "Allow read activity log" ON gadai_activity_logs
  FOR SELECT USING (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════
-- 6. PASTIKAN KOLOM STATUS ADA DI gadai_transactions
-- ════════════════════════════════════════════════════════════════
-- Uncomment jika kolom belum ada:
-- ALTER TABLE gadai_transactions ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Aktif';
