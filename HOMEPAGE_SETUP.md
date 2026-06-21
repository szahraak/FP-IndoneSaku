# IndoneSaku - Homepage Setup Guide

## Files to add to your project

```
lib/
├── models/
│   ├── pertunjukan.dart       ← Pertunjukan data model
│   └── seniman.dart           ← Seniman data model
├── screens/
│   └── homepage_screen.dart   ← Full homepage UI (4 sections)
└── main.dart                  ← App entry point (updated)
```

## Firestore Collection Structure

### `pertunjukan` (collection)
```
{
  seniman_uid: string,
  judul: string,
  deskripsi: string,
  posterUrl: string,          // Cloudinary URL
  videoTeaserUrl: string?,
  kategori: string,           // e.g. "Gamelan", "Tari", "Wayang"
  kota: string,
  lokasi: GeoPoint?,
  tanggal: Timestamp,
  harga: number,
  stokTiket: number,
  status: "aktif" | "selesai" | "dibatalkan",
  dibuatPada: Timestamp,
  jumlahDipesan: number,      // ← needed for trending sort
  rating: number?
}
```

### `users` (collection)
```
{
  nama: string,
  email: string,
  fotoUrl: string,            // Cloudinary URL
  tipeAkun: "penonton" | "seniman" | "admin",
  preferensiSeni: string[],   // e.g. ["Gamelan", "Tari"]
  dibuatPada: Timestamp,
  cvPortofolioUrl: string?,   // only for seniman
  jumlahPertunjukan: number,  // only for seniman, for artist ranking
  rating: number?
}
```

## Required Firestore Composite Indexes

Create these in Firebase Console → Firestore → Indexes:

| Collection    | Fields                                          |
|---------------|-------------------------------------------------|
| pertunjukan   | status ASC, tanggal ASC                         |
| pertunjukan   | status ASC, tanggal ASC, kategori ASC           |
| pertunjukan   | status ASC, jumlahDipesan DESC                  |
| users         | tipeAkun ASC, jumlahPertunjukan DESC            |

## pubspec.yaml additions needed

Make sure these are in your dependencies (you already have them):
```yaml
dependencies:
  firebase_core: ^4.9.0
  cloud_firestore: ^6.4.1
  firebase_auth: ^6.5.1
```

## Navigation (TODO)
The homepage has several `// Navigate to ...` comments. Wire these up as you
build out the other screens:
- Show detail screen → pass `show.id`
- Search screen
- Artist profile screen → pass `artist.uid`
- All shows list screen (filterable by category)
- Notifications screen

## Homepage Sections Summary

1. **Pertunjukan Mendatang** — PageView banner with `tanggal > now`, ordered by date
2. **Rekomendasi Untukmu** — filtered by `user.preferensiSeni`, falls back to latest shows
3. **Lagi Trending** — ordered by `jumlahDipesan DESC`
4. **Seniman Pilihan** — `tipeAkun == "seniman"`, ordered by `jumlahPertunjukan DESC`
