import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  // Replace with your actual Cloudinary cloud name and unsigned upload preset
  static final String _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static const String _uploadPresetImage = 'indonesaku_posters';
  static const String _uploadPresetVideo = 'indonesaku_videos';
  static const String _uploadPresetDoc = 'indonesaku_seniman_docs';
  static const String _uploadPresetProfile = 'indonesaku_profiles';

  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';

  /// Upload an image file (poster). Returns the secure URL or throws.
  static Future<String> uploadPoster(File imageFile) async {
    return _upload(
      file: imageFile,
      resourceType: 'image',
      uploadPreset: _uploadPresetImage,
      folder: 'posters',
    );
  }

  /// Upload a video file (teaser). Returns the secure URL or throws.
  static Future<String> uploadVideoTeaser(File videoFile) async {
    return _upload(
      file: videoFile,
      resourceType: 'video',
      uploadPreset: _uploadPresetVideo,
      folder: 'teasers',
    );
  }

  /// Upload a document file (CV / Portfolio). Returns the secure URL or throws.
  static Future<String> uploadDocument(File docFile) async {
    return _upload(
      file: docFile,
      // Gunakan 'auto' agar Cloudinary otomatis mengenali PDF/DOC tanpa merusaknya
      resourceType: 'auto', 
      uploadPreset: _uploadPresetDoc,
      folder: 'seniman_docs', 
    );
  }

  static Future<String> uploadProfilePicture(File imageFile) async {
    return _upload(
      file: imageFile,
      resourceType: 'image',
      uploadPreset: _uploadPresetProfile, // Gunakan preset yang baru
      folder: 'profiles', // Nama folder di Cloudinary
    );
  }

  static Future<String> _upload({
    required File file,
    required String resourceType,
    required String uploadPreset,
    required String folder,
  }) async {
    final uri = Uri.parse('$_baseUrl/$_cloudName/$resourceType/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String;
    } else {
      debugPrint('Cloudinary error: ${response.body}');
      throw Exception('Upload gagal: ${response.statusCode}');
    }
  }
}
