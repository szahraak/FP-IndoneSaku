const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const axios = require("axios");
const { onDocumentDeleted, onDocumentCreated } = require("firebase-functions/v2/firestore");
const cloudinary = require("cloudinary").v2;
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore(); // Inisialisasi database Firestore
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

// ── 1. FUNGSI CREATE SNAP TOKEN ──────────────────────────────────────────
exports.createSnapToken = onCall({ 
    region: 'asia-southeast2',
    secrets: ['MIDTRANS_SERVER_KEY']
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
    secrets: ['MIDTRANS_SERVER_KEY']
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
    let sendNotification = false;

    if (!orderId) {
        return res.status(400).send('Bad Request');
    }

    try {
        const orderRef = db.collection('pesanan').doc(orderId);
        const orderDoc = await orderRef.get();

        if (!orderDoc.exists) {
            console.log(`Webhook diabaikan: Pesanan dummy/test ${orderId} tidak ada di database.`);
            return res.status(200).send('OK'); 
        }

        let updateData = {};

        if (data.payment_type) {
          let specificType = data.payment_type;
          
          if (data.payment_type === 'bank_transfer' && data.va_numbers && data.va_numbers.length > 0) {
              specificType = `bank_transfer_${data.va_numbers[0].bank}`;
          } 
          else if (data.payment_type === 'cstore' && data.store) {
              specificType = `cstore_${data.store}`; 
          }
          
          updateData.midtransPaymentType = specificType;
        }

        if (transactionStatus === 'capture' || transactionStatus === 'settlement') {
          if (fraudStatus === 'challenge') {
              updateData.statusPembayaran = 'menunggu';
              updateData.statusPesanan = 'menunggu';
          } else {
              updateData.statusPembayaran = 'berhasil';
              updateData.statusPesanan = 'dikonfirmasi';
              sendNotification = true;
          }
        } else if (transactionStatus === 'deny' || transactionStatus === 'cancel' || transactionStatus === 'expire') {
          updateData.statusPembayaran = 'gagal';
          updateData.statusPesanan = 'dibatalkan';
        } else if (transactionStatus === 'pending') {
          updateData.statusPembayaran = 'menunggu';
          updateData.statusPesanan = 'menunggu';
        }

        if (data.expiry_time) {
          const isoString = data.expiry_time.replace(' ', 'T') + '+07:00';
          updateData.batasWaktuPembayaran = Timestamp.fromDate(new Date(isoString));
        }

        if (Object.keys(updateData).length > 0) {
          await orderRef.update(updateData);
        }

        // 3. Kirim notifikasi FCM jika pembayaran berhasil
        if (sendNotification) {
            const pesananData = orderDoc.data();
            const userDoc = await db.collection('users').doc(pesananData.penggunaUid).get();
            
            if (userDoc.exists && userDoc.data().fcmToken) {
                const fcmToken = userDoc.data().fcmToken;
                
                // Parsing tanggal aman
                let tanggalIso = new Date().toISOString();
                if (pesananData.tanggalPertunjukan) {
                    tanggalIso = typeof pesananData.tanggalPertunjukan.toDate === 'function' 
                        ? pesananData.tanggalPertunjukan.toDate().toISOString()
                        : new Date(pesananData.tanggalPertunjukan).toISOString();
                }
                
                const message = {
                    data: {
                        title: String("Pembayaran Berhasil! 🎉"),
                        body: String(`Tiket untuk pertunjukan ${pesananData.judulPertunjukan || 'Anda'} telah dikonfirmasi.`),
                        action: String("payment_success"),
                        pesananId: String(pesananData.id || orderId),
                        judulPertunjukan: String(pesananData.judulPertunjukan || 'Pertunjukan'),
                        tanggalPertunjukan: String(tanggalIso),
                    },
                    token: fcmToken
                };

                await getMessaging().send(message)
                    .then(() => console.log("FCM terkirim ke", pesananData.penggunaUid))
                    .catch(err => console.error("Gagal kirim FCM:", err));
            }
        }

        res.status(200).send('OK');
    } catch (error) {
        console.error('Error handling webhook:', error);
        res.status(500).send('Internal Server Error');
    }
});

// ── 4. HELPER GET PUBLIC ID CLOUDINARY DARI URL ─────────────────
function extractPublicId(url) {
  try {
    const parts = url.split('/');
    const uploadIndex = parts.indexOf('upload');
    if (uploadIndex !== -1) {
      // Ambil sisa path setelah folder 'upload/v123456/'
      const publicIdWithExt = parts.slice(uploadIndex + 2).join('/');
      // Hilangkan ekstensi file (.jpg, .mp4, dll)
      const publicId = publicIdWithExt.split('.')[0]; 
      return publicId;
    }
  } catch (e) {
    console.error("Error parsing URL:", e);
  }
  return null;
}

// ── 5. TRIGGER FIRESTORE UNTUK MENGHAPUS MEDIA DI CLOUDINARY ─────────────────
exports.hapusMediaCloudinary = onDocumentDeleted("pertunjukan/{docId}", async (event) => {
  const deletedData = event.data.data();
  const posterUrl = deletedData.posterUrl;
  const videoUrl = deletedData.videoTeaserUrl;
  const senimanUid = deletedData.seniman_uid;

  const deletePromises = [];

  if (posterUrl) {
    const publicId = extractPublicId(posterUrl);
    if (publicId) deletePromises.push(cloudinary.uploader.destroy(publicId, { resource_type: 'image' }));
  }

  if (videoUrl) {
    const publicId = extractPublicId(videoUrl);
    if (publicId) deletePromises.push(cloudinary.uploader.destroy(publicId, { resource_type: 'video' }));
  }

  if (senimanUid) {
    const senimanRef = db.collection('seniman').doc(senimanUid);
    // Kita gunakan promise push agar berjalan bersamaan dengan hapus gambar
    deletePromises.push(
      senimanRef.update({
        jumlahPertunjukan: FieldValue.increment(-1)
      }).catch(e => console.log("Seniman mungkin sudah dihapus duluan", e))
    );
  }

  try {
    await Promise.all(deletePromises);
    console.log(`Media terhapus untuk dokumen ${event.params.docId}`);
  } catch (error) {
    console.error("Gagal menghapus file:", error);
  }
});

// ── 6. FUNGSI MANUAL UNTUK MENGHAPUS MEDIA DI CLOUDINARY (DIPANGGIL DARI FLUTTER) ──
exports.deleteMediaCloudinary = onCall({ region: 'asia-southeast2' }, async (request) => {
    const url = request.data.url;
    const resourceType = request.data.resourceType || 'image';

    if (!url) {
        throw new HttpsError('invalid-argument', 'URL media wajib disertakan.');
    }

    const publicId = extractPublicId(url);
    if (!publicId) {
        throw new HttpsError('invalid-argument', 'Public ID tidak ditemukan dari URL tersebut.');
    }

    try {
        await cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
        console.log(`Media dihapus secara manual: ${publicId}`);
        return { success: true, message: 'Media berhasil dihapus dari Cloudinary' };
    } catch (error) {
        console.error("Gagal hapus media manual:", error);
        throw new HttpsError('internal', `Gagal menghapus di Cloudinary: ${error.message}`);
    }
});

// ── 7. TRIGGER FIRESTORE UNTUK MENAMBAH JUMLAH PERTUNJUKAN ─────────────────
exports.tambahJumlahPertunjukan = onDocumentCreated("pertunjukan/{docId}", async (event) => {
  const data = event.data.data();
  const senimanUid = data.seniman_uid;

  if (senimanUid) {
    const senimanRef = db.collection('seniman').doc(senimanUid);
    try {
      await senimanRef.update({
        jumlahPertunjukan: FieldValue.increment(1) 
      });
      console.log(`Berhasil menambah jumlahPertunjukan untuk seniman: ${senimanUid}`);
    } catch (error) {
      console.error("Gagal menambah jumlahPertunjukan:", error);
    }
  }
});