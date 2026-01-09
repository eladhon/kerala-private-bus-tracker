import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseStorageService {
  final _client = Supabase.instance.client;
  static const String _bucketName = 'conductor_uploads';

  /// Uploads a file to the conductor_uploads bucket and returns the public URL.
  ///
  /// [file] is the local file to upload.
  /// [folder] is an optional subfolder path (e.g., 'userId/busId').
  Future<String?> uploadFile(File file, {String folder = 'uploads'}) async {
    try {
      final fileName = '${const Uuid().v4()}_${file.path.split('/').last}';
      final path = '$folder/$fileName';

      await _client.storage
          .from(_bucketName)
          .upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = _client.storage.from(_bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      // Handle or rethrow based on app needs
      // For now, simple error printing
      // debugPrint('Error uploading file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Deletes a file from storage given its path or URL (parsing needed if URL).
  Future<void> deleteFile(String path) async {
    try {
      await _client.storage.from(_bucketName).remove([path]);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
