import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ProfilePictureService {
  static final supabase = Supabase.instance.client;
  static const String _bucketName = 'profilepic';

  /// Upload a profile picture for a user
  static Future<String> uploadProfilePicture({
    required String userId,
    required File imageFile,
  }) async {
    try {
      // Debug: Check authentication
      final user = supabase.auth.currentUser;
      print('🔍 Debug - Authenticated User: ${user?.id}');
      print('🔍 Debug - User Email: ${user?.email}');

      if (user == null) {
        throw Exception('❌ User not authenticated. Please login first.');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = imageFile.path.split('/').last;
      final uploadFileName = 'profile_${userId}_${timestamp}_$fileName';
      final filePath = 'profile_pictures/$uploadFileName'; // Simple path

      print('📤 Uploading to: $filePath');

      // Upload to profilepic bucket
      await supabase.storage.from(_bucketName).uploadBinary(
            filePath,
            await imageFile.readAsBytes(),
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl =
          supabase.storage.from(_bucketName).getPublicUrl(filePath);

      print('✅ Profile picture uploaded: $publicUrl');
      return publicUrl;
    } on StorageException catch (e) {
      print('❌ Storage Error: ${e.statusCode} - ${e.message}');
      print('   Error details: ${e.error}');
      rethrow;
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Delete an old profile picture
  static Future<void> deleteProfilePicture({
    required String userId,
    required String filePath,
  }) async {
    try {
      // Extract just the filename from the full path
      final fileName = filePath.split('/').last;
      final fullPath = '$userId/$fileName';

      await supabase.storage.from(_bucketName).remove([fullPath]);
      print('✓ Profile picture deleted');
    } catch (e) {
      print('✗ Error deleting profile picture: $e');
      // Don't rethrow - deletion errors shouldn't break the app
    }
  }

  /// Update user's profile picture URL in database
  static Future<void> updateProfilePictureInDatabase({
    required String userId,
    required String pictureUrl,
  }) async {
    try {
      await supabase.from('users').update({
        'profile_picture': pictureUrl,
      }).eq('id', userId);

      print('✓ Profile picture URL updated in database');
    } catch (e) {
      print('✗ Error updating profile picture in database: $e');
      rethrow;
    }
  }
}
