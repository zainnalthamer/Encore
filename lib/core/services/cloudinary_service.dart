import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = "doctomog7";
  static const String uploadPreset = "encore_avatar";

  Future<String> uploadAvatar(XFile file) async {
    return _uploadImage(
      file: file,
      folder: 'avatars',
    );
  }

  Future<String> uploadHeaderImage(XFile file) async {
    return _uploadImage(
      file: file,
      folder: 'headers',
    );
  }

  Future<String> _uploadImage({
    required XFile file,
    required String folder,
  }) async {
    final uri =
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    final request = http.MultipartRequest("POST", uri)
      ..fields["upload_preset"] = uploadPreset
      ..fields["folder"] = folder;

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: file.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath("file", file.path),
      );
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Cloudinary upload failed: $body");
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    return data["secure_url"] as String;
  }
}