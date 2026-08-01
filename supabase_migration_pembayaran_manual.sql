-- ============================================================
-- MIGRATION: Pembayaran Manual + FCM Push Notification
-- Jalankan di Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Tambah kolom baru di gadai_transactions & perbarui constraint status
ALTER TABLE gadai_transactions
  ADD COLUMN IF NOT EXISTS payment_proof_url       TEXT,
  ADD COLUMN IF NOT EXISTS payment_requested_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_verified_at     TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_verified_by     TEXT,
  ADD COLUMN IF NOT EXISTS payment_type            TEXT, -- 'perpanjang' | 'tebus'
  ADD COLUMN IF NOT EXISTS payment_period_days     INT,
  ADD COLUMN IF NOT EXISTS payment_reject_reason   TEXT;

-- Hapus constraint status lama & tambahkan seluruh status yang digunakan di aplikasi
ALTER TABLE gadai_transactions
  DROP CONSTRAINT IF EXISTS gadai_transactions_status_check;

ALTER TABLE gadai_transactions
  ADD CONSTRAINT gadai_transactions_status_check
  CHECK (status IN ('Aktif', 'Macet', 'Lunas', 'Lelang', 'Menunggu Verifikasi', 'Menunggu Pengambilan', 'Dibatalkan', 'Terjual', 'Perlu_Bayar_Jatip'));

-- 2. Tabel rekening bank gadai
CREATE TABLE IF NOT EXISTS gadai_rekening (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  branch_id      TEXT,
  bank_name      TEXT NOT NULL,
  account_number TEXT NOT NULL,
  account_name   TEXT NOT NULL,
  is_active      BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Pastikan kolom branch_id ada jika tabel sudah pernah dibuat sebelumnya
ALTER TABLE gadai_rekening
  ADD COLUMN IF NOT EXISTS branch_id TEXT;

-- Seed data rekening contoh (ganti sesuai rekening asli)
INSERT INTO gadai_rekening (bank_name, account_number, account_name, is_active)
VALUES 
  ('BCA', '1234567890', 'Galaxi Gadai', TRUE),
  ('BRI', '0987654321', 'Galaxi Gadai', TRUE)
ON CONFLICT DO NOTHING;

-- 3. Tambah kolom FCM token di tabel profiles (untuk push notification)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS fcm_token TEXT,
  ADD COLUMN IF NOT EXISTS fcm_updated_at TIMESTAMPTZ;

-- 4. Tambah kolom FCM token di tabel gadai_nasabah_accounts (untuk nasabah)
ALTER TABLE gadai_nasabah_accounts
  ADD COLUMN IF NOT EXISTS fcm_token TEXT,
  ADD COLUMN IF NOT EXISTS fcm_updated_at TIMESTAMPTZ;

-- 5. RLS Policies untuk gadai_rekening
ALTER TABLE gadai_rekening ENABLE ROW LEVEL SECURITY;

-- Semua user (nasabah anon & authenticated) dapat membaca rekening aktif
DROP POLICY IF EXISTS "rekening_select_authenticated" ON gadai_rekening;
DROP POLICY IF EXISTS "rekening_select_public" ON gadai_rekening;
CREATE POLICY "rekening_select_public" ON gadai_rekening
  FOR SELECT TO public
  USING (is_active = TRUE);

-- Pengelolaan rekening (insert, update, delete) untuk public/admin
DROP POLICY IF EXISTS "rekening_manage_superadmin" ON gadai_rekening;
DROP POLICY IF EXISTS "rekening_manage_public" ON gadai_rekening;
CREATE POLICY "rekening_manage_public" ON gadai_rekening
  FOR ALL TO public
  USING (TRUE)
  WITH CHECK (TRUE);

-- 6. Indeks untuk query payment pending
CREATE INDEX IF NOT EXISTS idx_gadai_tx_status ON gadai_transactions(status);
CREATE INDEX IF NOT EXISTS idx_gadai_tx_payment_requested ON gadai_transactions(payment_requested_at DESC NULLS LAST);

-- 7. RPC: Fungsi untuk verifikasi pembayaran perpanjang tenor
DROP FUNCTION IF EXISTS verify_perpanjang_payment(UUID, TEXT, TIMESTAMPTZ, INT, INT, INT);
DROP FUNCTION IF EXISTS verify_perpanjang_payment(TEXT, TEXT, TIMESTAMPTZ, INT, INT, INT);

CREATE OR REPLACE FUNCTION verify_perpanjang_payment(
  p_tx_id TEXT,
  p_admin_id TEXT,
  p_new_due_date TIMESTAMPTZ,
  p_period_days INT,
  p_total_fee INT,
  p_total_repayment INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_old_due_date TIMESTAMPTZ;
BEGIN
  -- Simpan jatuh tempo lama sebelum update
  SELECT date_due INTO v_old_due_date FROM gadai_transactions WHERE id::text = p_tx_id;

  -- Update transaksi
  UPDATE gadai_transactions
  SET
    status               = 'Aktif',
    date_due             = p_new_due_date,
    period_days          = p_period_days,
    total_fee            = p_total_fee,
    total_repayment      = p_total_repayment,
    payment_verified_at  = NOW(),
    payment_verified_by  = p_admin_id
  WHERE id::text = p_tx_id;

  -- Simpan ke extension history jika memungkinkan
  BEGIN
    INSERT INTO gadai_extension_history (
      transaction_id,
      jatip_dibayar,
      tgl_perpanjangan,
      tgl_tempo_lama,
      tgl_tempo_baru
    )
    VALUES (
      p_tx_id::uuid,
      p_total_fee,
      NOW(),
      v_old_due_date,
      p_new_due_date
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END;
$$;

-- 8. RPC: Fungsi untuk verifikasi pembayaran tebus
DROP FUNCTION IF EXISTS verify_tebus_payment(UUID, TEXT);
DROP FUNCTION IF EXISTS verify_tebus_payment(TEXT, TEXT);

CREATE OR REPLACE FUNCTION verify_tebus_payment(
  p_tx_id TEXT,
  p_admin_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE gadai_transactions
  SET
    status               = 'Menunggu Pengambilan',
    payment_verified_at  = NOW(),
    payment_verified_by  = p_admin_id
  WHERE id::text = p_tx_id;
END;
$$;

-- Done!
SELECT 'Migration pembayaran manual berhasil diterapkan!' AS result;
