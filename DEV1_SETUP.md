# IndoneSaku — Dev 1: Manajemen Pertunjukan
## Files Added (branch: jan0 continuation)

```
lib/
├── services/
│   ├── cloudinary_service.dart    ← Upload poster & video teaser to Cloudinary
│   └── pertunjukan_service.dart   ← Full CRUD + browse/filter queries
├── screens/
│   ├── homepage_screen.dart       ← (UPDATED) all navigation wired up
│   ├── show_detail_screen.dart    ← Audience detail view + Google Maps + video
│   ├── browse_shows_screen.dart   ← Browse & filter (category, city, search)
│   ├── create_edit_show_screen.dart ← Seniman create/edit form
│   ├── location_picker_screen.dart  ← Google Places Autocomplete picker
│   └── my_shows_screen.dart       ← Seniman show management (list/cancel/delete)
```

---

## pubspec.yaml — New Dependencies
Add these to `dependencies:` (already updated in the file):
```yaml
image_picker: ^1.1.2
http: ^1.2.0
url_launcher: ^6.3.0
```
Then run: `flutter pub get`

---

## Required API Keys — Replace Placeholders

### 1. Google Maps API Key
Replace `YOUR_GOOGLE_MAPS_API_KEY` in:
- `lib/screens/show_detail_screen.dart` (Static Maps + deep-link)
- `lib/screens/location_picker_screen.dart` (Places Autocomplete)

Enable these APIs in Google Cloud Console:
- **Maps Static API** — for map thumbnail on detail screen
- **Places API** — for location autocomplete
- **Geocoding API** (optional)

### 2. Cloudinary Config
Replace in `lib/services/cloudinary_service.dart`:
```dart
static const String _cloudName = 'YOUR_CLOUD_NAME';
static const String _uploadPresetImage = 'indonesaku_posters';
static const String _uploadPresetVideo = 'indonesaku_videos';
```

In Cloudinary dashboard → Settings → Upload:
- Create unsigned upload preset `indonesaku_posters` (images)
- Create unsigned upload preset `indonesaku_videos` (videos, max 50MB)

---

## Android Setup

### AndroidManifest.xml
Add inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```

Add Google Maps API key inside `<application>`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

---

## iOS Setup

### Info.plist — Add photo access descriptions:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Diperlukan untuk memilih poster dan video pertunjukan</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Diperlukan untuk menyimpan gambar</string>
```

---

## Navigation Flow Summary

```
HomepageScreen
├── [Search bar tap]        → BrowseShowsScreen
├── [Category chip tap]     → BrowseShowsScreen (pre-filtered)
├── [Show card tap]         → ShowDetailScreen
├── [See All button]        → BrowseShowsScreen
│
BrowseShowsScreen
└── [Show card tap]         → ShowDetailScreen
│
ShowDetailScreen
└── [Lokasi card tap]       → Google Maps (external)
└── [Video teaser tap]      → Video URL (external)
└── [Pesan Tiket button]    → BookingScreen (TODO: Dev responsible for booking)
│
MyShowsScreen               ← accessible from profile/nav
├── [FAB / + button]        → CreateEditShowScreen (create)
├── [Show tile tap]         → ShowDetailScreen
├── [⋮ Edit]               → CreateEditShowScreen (edit, pre-filled)
├── [⋮ Batalkan]           → soft-delete (status = 'dibatalkan')
└── [⋮ Hapus]              → hard-delete from Firestore
│
CreateEditShowScreen
└── [Pilih Lokasi button]   → LocationPickerScreen → back with GeoPoint
```

---

## Firestore Security Rules (add to your rules)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /pertunjukan/{docId} {
      // Anyone can read active shows
      allow read: if true;
      // Only authenticated seniman can create
      allow create: if request.auth != null
        && request.resource.data.seniman_uid == request.auth.uid;
      // Only the owner can update/delete
      allow update, delete: if request.auth != null
        && resource.data.seniman_uid == request.auth.uid;
    }
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## How to Access MyShowsScreen
Wire it into your app's navigation (bottom nav or drawer). Example:
```dart
// In your main navigation, add a tab for seniman:
NavigationDestination(icon: Icon(Icons.dashboard), label: 'Pertunjukan Saya')

// And navigate to:
MyShowsScreen()
```

---

## Extra Credit: Cloud Storage (Cloudinary)
- Poster images → uploaded via `CloudinaryService.uploadPoster()`
- Video teasers → uploaded via `CloudinaryService.uploadVideoTeaser()`
- Both are stored with Cloudinary URLs saved to Firestore `pertunjukan` documents
- The upload preset must be **unsigned** so no API secret is needed client-side

---

## Composite Firestore Indexes Required
Create in Firebase Console → Firestore → Indexes:

| Collection   | Fields                                  |
|--------------|-----------------------------------------|
| pertunjukan  | status ASC, tanggal ASC                 |
| pertunjukan  | status ASC, tanggal ASC, kategori ASC   |
| pertunjukan  | status ASC, jumlahDipesan DESC          |
| pertunjukan  | seniman_uid ASC, dibuatPada DESC        |
| users        | tipeAkun ASC, jumlahPertunjukan DESC    |
