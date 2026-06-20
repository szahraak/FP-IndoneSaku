const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const axios = require("axios");

initializeApp();
const db = getFirestore(); // Inisialisasi database Firestore

// ── 1. FUNGSI CREATE SNAP TOKEN ──────────────────────────────────────────
exports.createSnapToken = onCall({ 
    region: 'asia-southeast2',
    secrets: ['MIDTRANS_SERVER_KEY'] // Mendaftarkan secret ke fungsi ini
}, async (request) => {
    const data = request.data;
    
    // Memanggil secret dari environment variable
    const serverKey = process.env.MIDTRANS_SERVER_KEY; 
    const encodedKey = Buffer.from(serverKey + ':').toString('base64');

    const payload = {
        transaction_details: {
            order_id: data.orderId,
            gross_amount: data.grossAmount
        },
        customer_details: {
            first_name: data.namaPemesan,
            email: data.emailPemesan
        },
        item_details: data.items,
        callbacks: {
            finish: "https://fp-indonesaku.web.app/payment/finish",
            error: "https://fp-indonesaku.web.app/payment/error",
            pending: "https://fp-indonesaku.web.app/payment/pending"
        },
        enabled_payments: [
            "credit_card",
            "bca_va",
            "bni_va",
            "echannel",
            "bri_va",
            "permata_va",
            "cimb_va",
            "danamon_va",
            "bsi_va",
            "seabank_va",
            "saqu_va",
            "gopay",
            "shopeepay",
            "ovo",
            "dana",
            "indomaret",
            "alfamart",
            "akulaku"
        ],
    };

    try {
        const response = await axios.post(
            'https://app.sandbox.midtrans.com/snap/v1/transactions',
            payload,
            {
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'Authorization': `Basic ${encodedKey}`
                }
            }
        );

        return {
            snapToken: response.data.token,
            redirectUrl: response.data.redirect_url
        };
    } catch (error) {
        const midtransError = error.response && error.response.data 
            ? JSON.stringify(error.response.data.error_messages || error.response.data) 
            : error.message;
        console.error("Midtrans Error:", midtransError);
        throw new HttpsError('internal', `Gagal dari Midtrans: ${midtransError}`);
    }
});

// ── 2. FUNGSI CANCEL TRANSAKSI ───────────────────────────────────────────
exports.cancelMidtransTransaction = onCall({ 
    region: 'asia-southeast2',
    secrets: ['MIDTRANS_SERVER_KEY'] // Mendaftarkan secret ke fungsi ini juga
}, async (request) => {
    const orderId = request.data.orderId;

    if (!orderId) {
        throw new HttpsError('invalid-argument', 'Order ID wajib disertakan.');
    }

    // Memanggil secret dari environment variable
    const serverKey = process.env.MIDTRANS_SERVER_KEY; 
    const encodedKey = Buffer.from(serverKey + ':').toString('base64');

    try {
        const response = await axios.post(
            `https://api.sandbox.midtrans.com/v2/${orderId}/cancel`,
            {},
            {
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'Authorization': `Basic ${encodedKey}`
                }
            }
        );

        return {
            success: true,
            message: 'Transaksi berhasil dibatalkan di Midtrans',
            midtransResponse: response.data
        };
    } catch (error) {
        const errorMessage = error.response ? error.response.data.status_message : error.message;
        throw new HttpsError('internal', `Gagal membatalkan di Midtrans: ${errorMessage}`);
    }
});

// ── 3. FUNGSI WEBHOOK (Dipanggil otomatis oleh Midtrans) ─────────────────
exports.midtransWebhook = onRequest({ region: 'asia-southeast2' }, async (req, res) => {
    const data = req.body;
    const orderId = data.order_id;
    const transactionStatus = data.transaction_status;
    const fraudStatus = data.fraud_status;

    // Pastikan request memiliki order_id
    if (!orderId) {
        res.status(400).send('Bad Request');
        return;
    }

    try {
        const orderRef = db.collection('pesanan').doc(orderId);
        let updateData = {};

        if (data.payment_type) {
          let specificType = data.payment_type;
          
          if (data.payment_type === 'bank_transfer' && data.va_numbers && data.va_numbers.length > 0) {
              specificType = `bank_transfer_${data.va_numbers[0].bank}`;
          } 
          else if (data.payment_type === 'cstore' && data.store) {
              specificType = `cstore_${data.store}`; // Hasil: cstore_alfamart
          }
          
          updateData.midtransPaymentType = specificType;
        }

        // 1. Logika status
        if (transactionStatus === 'capture' || transactionStatus === 'settlement') {
          if (fraudStatus === 'challenge') {
              updateData.statusPembayaran = 'menunggu';
              updateData.statusPesanan = 'menunggu';
          } else {
              updateData.statusPembayaran = 'berhasil';
              updateData.statusPesanan = 'dikonfirmasi';
          }
        } else if (transactionStatus === 'deny' || transactionStatus === 'cancel' || transactionStatus === 'expire') {
          updateData.statusPembayaran = 'gagal';
          updateData.statusPesanan = 'dibatalkan';
        } else if (transactionStatus === 'pending') {
          updateData.statusPembayaran = 'menunggu';
          updateData.statusPesanan = 'menunggu';
        }

        // 2. Tangkap expiry_time dari Midtrans
        if (data.expiry_time) {
          // Midtrans mengirim format "YYYY-MM-DD HH:mm:ss" dalam zona waktu WIB
          // Ubah menjadi format ISO agar bisa dibaca oleh Date Node.js
          const isoString = data.expiry_time.replace(' ', 'T') + '+07:00';
          updateData.batasWaktuPembayaran = Timestamp.fromDate(new Date(isoString));
        }

        if (Object.keys(updateData).length > 0) {
          await orderRef.update(updateData);
        }

        res.status(200).send('OK');
    } catch (error) {
        console.error('Error handling webhook:', error);
        res.status(500).send('Internal Server Error');
    }
});