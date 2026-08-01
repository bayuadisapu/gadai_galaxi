import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts"

// ============================================================
// SUPABASE EDGE FUNCTION — MIDTRANS WEBHOOK NOTIFICATION
// Handling otomatis status pembayaran dari Midtrans (Settlement)
// ============================================================

serve(async (req) => {
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers })
  }

  try {
    const body = await req.json()
    const {
      order_id,
      status_code,
      gross_amount,
      signature_key,
      transaction_status,
      fraud_status,
      payment_type,
    } = body

    console.log(`[Midtrans Webhook] Received notification for Order ID: ${order_id}, status: ${transaction_status}`)

    const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY') ?? ''

    // 1. Verifikasi Signature Key Midtrans (SHA-512)
    if (serverKey && signature_key) {
      const inputStr = `${order_id}${status_code}${gross_amount}${serverKey}`
      const encoder = new TextEncoder()
      const data = encoder.encode(inputStr)
      const hashBuffer = await crypto.subtle.digest('SHA-512', data)
      const hashArray = Array.from(new Uint8Array(hashBuffer))
      const expectedSignature = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

      if (signature_key !== expectedSignature) {
        console.error('[Midtrans Webhook] Invalid Signature Key!')
        return new Response(JSON.stringify({ error: 'Invalid signature key' }), {
          status: 400,
          headers,
        })
      }
    }

    // 2. Cek apakah status pembayaran sukses (settlement atau capture accept)
    const isSuccess =
      transaction_status === 'settlement' ||
      (transaction_status === 'capture' && fraud_status === 'accept')

    if (isSuccess && order_id.startsWith('GADAI-EXT-')) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
      const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY') ?? ''

      if (supabaseUrl && supabaseServiceKey) {
        const supabase = createClient(supabaseUrl, supabaseServiceKey)

        const parts = order_id.split('-')
        if (parts.length >= 5) {
          // Format: GADAI-EXT-{txId}-{days}-{timestamp}
          // txId = GTX-2026-XXXX (3 parts), days = 15 or 30, timestamp = last part
          // parts = ["GADAI", "EXT", "GTX", "2026", "XXXX", "15", "1721..."]
          const timestamp = parts[parts.length - 1]
          const daysStr = parts[parts.length - 2]
          const periodDaysFromOrder = parseInt(daysStr)
          const txId = parts.slice(2, parts.length - 2).join('-')
          const paidAmount = Math.round(parseFloat(gross_amount))

          // Validasi: daysStr harus angka (15 atau 30)
          const periodDays = (!isNaN(periodDaysFromOrder) && periodDaysFromOrder > 0)
            ? periodDaysFromOrder
            : 30 // fallback jika format lama tanpa days

          console.log(`[Midtrans Webhook] txId=${txId}, days=${periodDays}, amount=${paidAmount}, payment=${payment_type}`)

          // Fetch current pawn transaction
          const { data: tx, error: fetchErr } = await supabase
            .from('gadai_transactions')
            .select('*')
            .eq('id', txId)
            .single()

          if (!fetchErr && tx) {
            const currentDue = new Date(tx.date_due)
            const now = new Date()
            // Jika macet (date_due sudah lewat), hitung dari hari ini — konsisten dengan Flutter app
            const baseDate = currentDue < now ? now : currentDue
            const newDue = new Date(baseDate.getTime() + periodDays * 24 * 60 * 60 * 1000)

            // Cek duplikasi: apakah sudah pernah diproses untuk order_id ini?
            // Midtrans bisa kirim notifikasi berkali-kali untuk 1 transaksi.
            const { data: existing } = await supabase
              .from('gadai_extension_history')
              .select('id')
              .eq('transaction_id', txId)
              .eq('jatip_dibayar', paidAmount)
              .eq('tgl_tempo_baru', newDue.toISOString())
              .limit(1)

            if (existing && existing.length > 0) {
              console.log(`[Midtrans Webhook] Duplicate notification ignored for tx ${txId}`)
            } else {
              // 1. Catat ke riwayat perpanjangan
              await supabase.from('gadai_extension_history').insert({
                transaction_id: txId,
                tgl_perpanjangan: new Date().toISOString(),
                jatip_dibayar: paidAmount,
                tgl_tempo_lama: currentDue.toISOString(),
                tgl_tempo_baru: newDue.toISOString(),
                payment_method: payment_type ?? '',
              })

              // 2. Hitung total_fee & total_repayment (konsisten dengan Flutter _applyExtension)
              const dailyFee = tx.daily_fee ?? 0
              const principal = tx.principal ?? 0
              const newTotalFee = dailyFee * periodDays
              const newTotalRepayment = principal + newTotalFee

              // 3. Update transaksi utama
              await supabase
                .from('gadai_transactions')
                .update({
                  date_due: newDue.toISOString(),
                  status: 'Aktif',
                  period_days: periodDays,
                  total_fee: newTotalFee,
                  total_repayment: newTotalRepayment,
                })
                .eq('id', txId)

              console.log(`[Midtrans Webhook] Successfully updated extension for tx ${txId}, new due: ${newDue.toISOString()}`)

              // Perpanjangan via Midtrans — tambah saldo rekening cabang
              const branchId = tx.branch_id
              if (branchId) {
                // Tambah saldo wallet cabang
                await supabase.rpc('gadai_wallet_topup', {
                  p_branch_id: branchId,
                  p_amount: paidAmount,
                })
                // Catat mutasi
                await supabase.from('gadai_wallet_mutations').insert({
                  branch_id: branchId,
                  type: 'Kredit',
                  amount: paidAmount,
                  description: `Jatip Perpanjangan via Midtrans - ${tx.brand ?? ''} ${tx.model ?? ''} (${txId})`,
                })
                console.log(`[Midtrans Webhook] Wallet topup Rp ${paidAmount} for branch ${branchId}`)
              }
            }
          } else {
            console.error(`[Midtrans Webhook] Transaction not found: ${txId}, error: ${fetchErr?.message}`)
          }
        }
      }
    }

    // ── PELUNASAN via nasabah app (GADAI-LUNAS-{txId}-{timestamp}) ──
    if (isSuccess && order_id.startsWith('GADAI-LUNAS-')) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
      const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY') ?? ''

      if (supabaseUrl && supabaseServiceKey) {
        const supabase = createClient(supabaseUrl, supabaseServiceKey)

        // Format: GADAI-LUNAS-{txId}-{timestamp}
        // parts = ["GADAI", "LUNAS", "GTX", "2026", "XXXX", "1721..."]
        const parts = order_id.split('-')
        if (parts.length >= 4) {
          const txId = parts.slice(2, parts.length - 1).join('-')
          const paidAmount = Math.round(parseFloat(gross_amount))

          console.log(`[Midtrans Webhook] LUNAS: txId=${txId}, amount=${paidAmount}`)

          const { data: tx, error: fetchErr } = await supabase
            .from('gadai_transactions')
            .select('*')
            .eq('id', txId)
            .single()

          if (!fetchErr && tx) {
            // Update status ke 'Menunggu Pengambilan'
            await supabase
              .from('gadai_transactions')
              .update({ status: 'Menunggu Pengambilan' })
              .eq('id', txId)

            // Tambah saldo rekening cabang
            const branchId = tx.branch_id
            if (branchId) {
              await supabase.rpc('gadai_wallet_topup', {
                p_branch_id: branchId,
                p_amount: paidAmount,
              })
              await supabase.from('gadai_wallet_mutations').insert({
                branch_id: branchId,
                type: 'Kredit',
                amount: paidAmount,
                description: `Pelunasan via Midtrans - ${tx.brand ?? ''} ${tx.model ?? ''} (${txId})`,
              })
            }

            console.log(`[Midtrans Webhook] Status set to Menunggu Pengambilan for tx ${txId}`)
          } else {
            console.error(`[Midtrans Webhook] LUNAS - Transaction not found: ${txId}`)
          }
        }
      }
    }

    return new Response(JSON.stringify({ status: 'OK', message: 'Notification processed' }), {
      status: 200,
      headers,
    })
  } catch (err) {
    console.error('[Midtrans Webhook] Exception:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers,
    })
  }
})
