import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// ============================================================
// SUPABASE EDGE FUNCTION — MIDTRANS SNAP PROXY
// POST /midtrans-snap  → buat Snap Token (create payment)
// GET  /midtrans-snap?order_id=xxx → cek status pembayaran
// Server Key disimpan di Supabase Secrets, tidak di client app.
// ============================================================

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY') ?? ''
  const env = Deno.env.get('MIDTRANS_ENV') ?? 'sandbox'

  if (!serverKey) {
    return new Response(JSON.stringify({ error: 'MIDTRANS_SERVER_KEY not configured' }), {
      status: 500,
      headers: corsHeaders,
    })
  }

  const authHeader = 'Basic ' + btoa(serverKey + ':')

  // ── GET: Cek status pembayaran ──
  if (req.method === 'GET') {
    const url = new URL(req.url)
    const orderId = url.searchParams.get('order_id')

    if (!orderId) {
      return new Response(JSON.stringify({ error: 'Missing order_id query parameter' }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const statusBaseUrl = env === 'production'
      ? 'https://api.midtrans.com/v2'
      : 'https://api.sandbox.midtrans.com/v2'

    console.log(`[midtrans-snap] Checking status: orderId=${orderId}, env=${env}`)

    const response = await fetch(`${statusBaseUrl}/${orderId}/status`, {
      method: 'GET',
      headers: { 'Authorization': authHeader },
    })

    const data = await response.json()

    if (response.ok) {
      return new Response(JSON.stringify(data), {
        status: 200,
        headers: corsHeaders,
      })
    } else {
      console.error(`[midtrans-snap] Status check error ${response.status}:`, data)
      return new Response(JSON.stringify({ error: `Midtrans error ${response.status}`, detail: data }), {
        status: response.status,
        headers: corsHeaders,
      })
    }
  }

  // ── POST: Buat Snap Token ──
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: corsHeaders,
    })
  }

  try {
    const body = await req.json() as {
      order_id: string
      gross_amount: number
      customer_name: string
      customer_phone?: string
      item_name: string
    }

    const { order_id, gross_amount, customer_name, customer_phone = '', item_name } = body

    if (!order_id || !gross_amount || !customer_name || !item_name) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const snapUrl = env === 'production'
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions'

    const truncatedName = item_name.length > 50 ? item_name.substring(0, 50) : item_name

    const midtransPayload = {
      transaction_details: {
        order_id,
        gross_amount,
      },
      customer_details: {
        first_name: customer_name,
        phone: customer_phone,
      },
      item_details: [
        {
          id: order_id.substring(0, 36), // max 36 chars
          price: gross_amount,
          quantity: 1,
          name: truncatedName,
        },
      ],
      callbacks: {
        finish: 'galaxigadai://payment/finish',
        error: 'galaxigadai://payment/error',
        pending: 'galaxigadai://payment/pending',
      },
    }

    console.log(`[midtrans-snap] Creating snap token: orderId=${order_id}, amount=${gross_amount}, env=${env}`)

    const response = await fetch(snapUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
      body: JSON.stringify(midtransPayload),
    })

    const data = await response.json()

    if (response.ok) {
      console.log(`[midtrans-snap] Success: token=${data.token}`)
      return new Response(JSON.stringify({
        token: data.token ?? '',
        redirect_url: data.redirect_url ?? '',
      }), {
        status: 200,
        headers: corsHeaders,
      })
    } else {
      console.error(`[midtrans-snap] Midtrans error ${response.status}:`, data)
      return new Response(JSON.stringify({
        error: `Midtrans error ${response.status}`,
        detail: data,
      }), {
        status: response.status,
        headers: corsHeaders,
      })
    }
  } catch (err) {
    console.error('[midtrans-snap] Exception:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
