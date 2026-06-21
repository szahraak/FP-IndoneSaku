# IndoneSaku - Project Documentation

## Overview

**IndoneSaku** is a Flutter mobile application for discovering and booking tickets to traditional Indonesian performing arts (seni pertunjukan tradisional). It connects audiences (penonton) with performers/artists (seniman) by letting users browse shows, buy tickets via Midtrans payment gateway, and manage their bookings.

- **Firebase Project ID**: `fp-indonesaku`
- **Repository**: `https://github.com/szahraak/FP-IndoneSaku`
- **Language**: Indonesian (Bahasa Indonesia) — all UI labels, field names, and Firestore collection/field names are in Indonesian.

## Tech Stack

- **Framework**: Flutter (Dart), SDK `>=3.11.0 <4.0.0`
- **Backend**: Firebase (Firestore, Firebase Auth, Cloud Functions)
- **Payment**: Midtrans Sandbox (via Cloud Functions for server-side token generation)
- **Media Storage**: Cloudinary (poster images, video teasers)
- **Font**: Google Fonts (Poppins)
- **Target Platforms**: Android, iOS, Web, Windows, macOS, Linux

## Project Structure

```
lib/
├── main.dart                         # App entry point, AuthGate, routing
├── firebase_options.dart             # FlutterFire CLI generated config
├── models/
│   ├── pertunjukan.dart              # Show/performance model (Firestore ↔ Dart)
│   ├── seniman.dart                  # Artist/performer model
│   ├── tiket.dart                    # Ticket order model (TiketPesanan, JenisTiket, enums)
│   └── user.dart                     # UserModel (penonton/seniman/admin)
├── screens/
│   ├── main_scaffold.dart            # Bottom nav scaffold (Home, Artikel, Profil)
│   ├── home_screen.dart              # Pertunjukan list (ticketing flow entry)
│   ├── homepage_screen.dart          # Rich homepage (upcoming, trending, recommended, artists)
│   ├── browse_shows_screen.dart      # Browse/filter shows by category, city, search
│   ├── show_detail_screen.dart       # Show detail page with video, map, description
│   ├── create_edit_show_screen.dart  # Seniman: create/edit a show (image picker, cloudinary)
│   ├── my_shows_screen.dart          # Seniman: manage own shows
│   ├── location_picker_screen.dart   # Location search using Nominatim API
│   ├── auth/
│   │   ├── login.dart                # Email/password login screen
│   │   ├── register.dart             # Registration (name, email, DOB, account type, art prefs)
│   │   └── forgot_password.dart      # Password reset screen
│   ├── ticketing/
│   │   ├── pesan_tiket_screen.dart   # Order tickets: pick ticket types & quantities
│   │   ├── rangkuman_pemesanan_screen.dart  # Order summary before payment
│   │   ├── midtrans_snap_screen.dart # WebView for Midtrans Snap payment page
│   │   └── tiketmu_screen.dart       # View purchased ticket details + QR code
│   └── profile/
│       └── profile_screen.dart       # User profile + ticket history (filtered by status)
├── services/
│   ├── auth_service.dart             # Firebase Auth wrapper (sign in, register, sign out)
│   ├── ticketing_service.dart        # Firestore ops for pertunjukan & pesanan (orders)
│   ├── midtrans_service.dart         # Cloud Function calls for Midtrans snap tokens
│   ├── pertunjukan_service.dart      # CRUD for pertunjukan collection (seniman features)
│   ├── cloudinary_service.dart       # Image/video upload to Cloudinary
│   └── mock_ticketing_service.dart   # Mock data for development/testing
functions/
├── index.js                          # Cloud Functions: createSnapToken, cancelMidtransTransaction, midtransWebhook
├── package.json                      # Node 22, firebase-functions v6, axios
```

## Key Concepts & Domain Terms (Indonesian)

| Indonesian Term | English | Description |
|---|---|---|
| Pertunjukan | Show/Performance | A traditional art performance event |
| Seniman | Artist/Performer | User with `tipeAkun: 'seniman'` who creates shows |
| Penonton | Audience/Viewer | Regular user who browses and buys tickets |
| Tiket / TiketPesanan | Ticket / Ticket Order | A booking with payment status |
| Jenis Tiket | Ticket Type | Sub-collection under each pertunjukan (e.g., VIP, Regular) |
| Pesanan | Order | Firestore collection storing ticket orders |
| Pesan Tiket | Order Ticket | The action of booking a ticket |
| Rangkuman | Summary | Order summary screen before payment |
| Profil | Profile | User profile page |
| Artikel | Article | Placeholder tab (not yet implemented) |

## Firestore Collections

- **`users`**: User profiles (`UserModel`) — fields: `nama`, `email`, `fotoUrl`, `tipeAkun` (penonton/seniman/admin), `preferensiSeni`, `tanggalLahir`, `createdAt`
- **`pertunjukan`**: Shows/performances — fields: `seniman_uid`, `judul`, `deskripsi`, `posterUrl`, `videoTeaserUrl`, `kategori`, `kota`, `lokasi` (GeoPoint), `tanggal`, `harga`, `stokTiket`, `status`, `dibuatPada`, `jumlahDipesan`, `rating`
  - **`pertunjukan/{id}/jenisTiket`**: Ticket types sub-collection — fields: `nama`, `harga`, `stok`, `deskripsi`
- **`pesanan`**: Ticket orders — fields: `penggunaUid`, `pertunjukanId`, `judulPertunjukan`, `posterUrl`, `tanggalPertunjukan`, `lokasi`, `namaPemesan`, `emailPemesan`, `items[]`, `totalHarga`, `statusPembayaran`, `statusPesanan`, `qrCodeData`, `snapToken`, `midtransOrderId`, `midtransPaymentType`, `batasWaktuPembayaran`

## Authentication Flow

1. App starts → `AuthGate` listens to `FirebaseAuth.authStateChanges()`
2. Not logged in → `LoginScreen` (email/password)
3. Logged in → `MainScaffold` (3-tab bottom nav: Home, Artikel, Profil)
4. Registration collects: name, email, password, date of birth, account type (penonton/seniman), art preferences (multi-select: Tari, Gamelan, Wayang, Musik, etc.)

## Ticketing & Payment Flow

1. User browses shows on `HomeScreen` → taps a show card
2. `PesanTiketScreen`: fetches `jenisTiket` sub-collection, user picks quantities
3. `RangkumanPemesananScreen`: order summary, total price
4. Calls `MidtransService.getSnapToken()` → invokes Cloud Function `createSnapToken`
5. `MidtransSnapScreen`: opens Midtrans Snap payment page in WebView
6. Midtrans sends webhook → Cloud Function `midtransWebhook` updates Firestore order status
7. `TiketmuScreen`: shows ticket details with QR code after successful payment

## Cloud Functions (functions/index.js)

All deployed to `asia-southeast2` region:
- **`createSnapToken`** (onCall): Creates Midtrans Snap transaction, returns `{ snapToken, redirectUrl }`
- **`cancelMidtransTransaction`** (onCall): Cancels a pending Midtrans transaction
- **`midtransWebhook`** (onRequest): HTTP endpoint for Midtrans payment status callbacks, updates Firestore `pesanan` document

**Secret**: `MIDTRANS_SERVER_KEY` (stored in Firebase Secrets, not in client code)

## App Colors & Theme

- Primary seed color: `#B5451B` (terracotta/batik)
- Scaffold background: `#F7F3EE` (warm cream)
- Accent blue: `#4B88A2` (used in ticketing/profile)
- Secondary navy: `#1A1A2E` (used in homepage)
- Gold accent: `#F5C842`
- Font: Poppins (via `google_fonts`)

## Show Categories

Tari, Gamelan, Wayang, Musik, Ludruk, Ketoprak, Reog, Lenong, Kecak, Angklung, Lainnya

## Build & Run

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Deploy Cloud Functions
cd functions && npm install && firebase deploy --only functions

# Generate launcher icons & splash screen
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Branch Structure

- `main` — stable/production branch
- `jan0` — homepage features, browse/create/edit shows, cloudinary, seniman management
- `dev-zahra` — auth system, ticketing with Midtrans payment, profile, navigation scaffold

## Important Notes

- The app uses Midtrans **Sandbox** environment — not production. The Cloud Function endpoint hits `app.sandbox.midtrans.com`.
- Cloudinary `_cloudName` in `cloudinary_service.dart` has a placeholder `'YOUR_CLOUD_NAME'` — must be replaced with actual cloud name.
- `homepage_screen.dart` (from jan0 branch) is a rich homepage with sections for upcoming, trending, recommended shows and artists. `home_screen.dart` (from dev-zahra branch) is a simpler pertunjukan list used inside `MainScaffold`. Both exist in the codebase.
- The `MainScaffold` currently uses `HomeScreen` (simpler list). To use the rich `HomepageScreen` instead, change the import in `main_scaffold.dart`.
- The `Artikel` tab in `MainScaffold` is a placeholder — not yet implemented.
- Location picker uses OpenStreetMap Nominatim API for geocoding (no Google Maps API key needed).
