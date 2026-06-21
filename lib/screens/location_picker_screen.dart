import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

/// A result from the location picker
class LocationResult {
  final String description;
  final double latitude;
  final double longitude;

  const LocationResult({
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);
}

/// Location picker that uses Google Places Autocomplete
/// Returns a [LocationResult] when user selects a place.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Replace with your actual Google Maps API key
  static const String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  final _searchController = TextEditingController();
  List<_PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  String? _errorMsg;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() {
      _searching = true;
      _errorMsg = null;
    });

    try {
      // Biased to Indonesia
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:id'
        '&language=id'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final predictions = data['predictions'] as List<dynamic>;
        setState(() {
          _suggestions = predictions
              .map((p) => _PlaceSuggestion(
                    placeId: p['place_id'] as String,
                    description: p['description'] as String,
                  ))
              .toList();
          _searching = false;
        });
      } else {
        setState(() {
          _errorMsg = 'Gagal memuat saran lokasi';
          _searching = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Tidak dapat terhubung ke layanan lokasi';
        _searching = false;
      });
    }
  }

  Future<void> _selectPlace(_PlaceSuggestion suggestion) async {
    setState(() => _searching = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${suggestion.placeId}'
        '&fields=geometry,formatted_address'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>;
        final location =
            result['geometry']['location'] as Map<String, dynamic>;

        final locationResult = LocationResult(
          description: result['formatted_address'] as String? ??
              suggestion.description,
          latitude: (location['lat'] as num).toDouble(),
          longitude: (location['lng'] as num).toDouble(),
        );

        if (mounted) {
          Navigator.pop(context, locationResult);
        }
      } else {
        setState(() {
          _errorMsg = 'Gagal mendapatkan detail lokasi';
          _searching = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Terjadi kesalahan';
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        title: const Text('Pilih Lokasi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search field
          Container(
            color: AppColors.secondary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari lokasi pertunjukan...',
                hintStyle:
                    TextStyle(color: Colors.white.withAlpha((0.5 * 255).round())),
                filled: true,
                fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _suggestions = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: _searchPlaces,
            ),
          ),

          // Error message
          if (_errorMsg != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMsg!,
                style:
                    const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),

          // Loading indicator
          if (_searching)
            const LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.divider),

          // Suggestions list
          Expanded(
            child: _suggestions.isEmpty && !_searching
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.location_on_outlined,
                            color: AppColors.textSecondary.withAlpha(
                                (0.4 * 255).round()),
                            size: 64),
                        const SizedBox(height: 12),
                        const Text(
                          'Ketik nama venue, kota, atau alamat',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withAlpha((0.1 * 255).round()),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_outlined,
                              color: AppColors.primary, size: 20),
                        ),
                        title: Text(
                          s.description,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        onTap: () => _selectPlace(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSuggestion {
  final String placeId;
  final String description;
  const _PlaceSuggestion({required this.placeId, required this.description});
}
