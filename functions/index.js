/* eslint-disable max-len */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const axios = require("axios");

initializeApp();

// ── Konfigurasi Midtrans Sandbox ─────────────────────────────────────────────
//
// Server Key disimpan sebagai Firebase Secret (TIDAK di source code).
// Set menggunakan:
//   firebase functions:secrets:set MIDTRANS_SERVER_KEY
//
// Untuk testing Sandbox, gunakan Server Key dari:
//   https://dashboard.sandbox.midtrans.com → Settings → Access Keys
//
const MIDTRANS_SNAP_URL =
  "https://app.sandbox.midtrans.com/snap/v1/transactions";

// Callback URL yang akan diintersep oleh WebView Flutter.
// Path /payment/* di Firebase Hosting bisa dikonfigurasi untuk halaman statis,
// namun WebView mengintersepnya sebelum loading — URL ini tidak perlu live.
const CALLBACK_BASE = "https://fp-indonesaku.web.app/payment";

// ── Cloud Function: createSnapToken ─────────────────────────────────────────

/**
 * Callable function yang dipanggil dari Flutter untuk mendapatkan
 * Midtrans Snap token.
 *
 * @param {object} data.orderId        ID pesanan (= ID dokumen Firestore)
 * @param {number} data.grossAmount    Total harga dalam Rupiah (integer)
 * @param {string} data.namaPemesan    Nama pemesan
 * @param {string} data.emailPemesan   Email pemesan
 * @param {Array}  data.items          Array item pesanan
 *
 * @returns {{ snapToken: string, redirectUrl: string }}
 */
exports.createSnapToken = onCall(
  {
    region: "asia-southeast2",
    secrets: ["MIDTRANS_SERVER_KEY"],
  },
  async (request) => {
    // Pastikan user sudah login
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Kamu harus login untuk melakukan pembayaran."
      );
    }

    const { orderId, grossAmount, namaPemesan, emailPemesan, items } =
      request.data;

    // Validasi input dasar
    if (!orderId || typeof orderId !== "string") {
      throw new HttpsError("invalid-argument", "orderId tidak valid.");
    }
    if (!grossAmount || typeof grossAmount !== "number" || grossAmount <= 0) {
      throw new HttpsError("invalid-argument", "grossAmount tidak valid.");
    }

    const serverKey = process.env.MIDTRANS_SERVER_KEY;
    if (!serverKey) {
      throw new HttpsError(
        "internal",
        "Konfigurasi server tidak lengkap. Hubungi admin."
      );
    }

    // Encode Server Key ke Base64 untuk Basic Auth
    const authHeader = Buffer.from(`${serverKey}:`).toString("base64");

    // Susun body request Midtrans Snap
    const snapBody = {
      transaction_details: {
        order_id: orderId,
        gross_amount: Math.round(grossAmount),
      },
      customer_details: {
        first_name: namaPemesan || "Pelanggan",
        email: emailPemesan || "",
      },
      item_details: Array.isArray(items)
        ? items.map((item) => ({
            id: item.id,
            price: Math.round(item.price),
            quantity: item.quantity,
            name: item.name,
          }))
        : [],
      callbacks: {
        // WebView Flutter akan mengintersep URL-URL ini.
        finish: `${CALLBACK_BASE}/finish`,
        error: `${CALLBACK_BASE}/error`,
        pending: `${CALLBACK_BASE}/pending`,
      },
    };

    try {
      const response = await axios.post(MIDTRANS_SNAP_URL, snapBody, {
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          Authorization: `Basic ${authHeader}`,
        },
        timeout: 15000, // 15 detik
      });

      const { token, redirect_url: redirectUrl } = response.data;

      if (!token || !redirectUrl) {
        throw new HttpsError(
          "internal",
          "Response Midtrans tidak mengandung token."
        );
      }

      return { snapToken: token, redirectUrl };
    } catch (error) {
      if (error instanceof HttpsError) throw error;

      const status = error.response?.status;
      const msg = error.response?.data?.error_messages?.[0] || error.message;

      if (status === 400) {
        throw new HttpsError("invalid-argument", `Midtrans: ${msg}`);
      } else if (status === 401) {
        throw new HttpsError(
          "permission-denied",
          "Server Key Midtrans tidak valid."
        );
      } else if (status === 409) {
        // order_id sudah pernah dipakai di Midtrans
        throw new HttpsError(
          "already-exists",
          "Order ID sudah digunakan di Midtrans."
        );
      }

      console.error("[createSnapToken] Midtrans error:", error.message);
      throw new HttpsError(
        "internal",
        "Gagal menghubungi Midtrans. Silakan coba lagi."
      );
    }
  }
);
