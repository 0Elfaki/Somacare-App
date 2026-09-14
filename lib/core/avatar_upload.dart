import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

/// Shared "change profile photo" flow for both the student and doctor
/// profile screens.
///
/// Shows a small "gallery or camera" chooser, picks an image, uploads it to
/// the `avatars` Supabase Storage bucket under the signed-in user's own
/// folder (`<user id>/avatar.<ext>` - the bucket's RLS policies only allow a
/// user to write inside their own folder), and writes the resulting public
/// URL onto `profiles.avatar_url`.
///
/// Returns the new avatar URL on success, or `null` if the user backed out
/// at any step (no source chosen, no image picked, not signed in). Throws on
/// an actual upload/network failure so the caller can show its own error.
Future<String?> changeProfilePhoto(BuildContext context) async {
  final source = await _askImageSource(context);
  if (source == null) return null;
  if (!context.mounted) return null;

  final picker = ImagePicker();
  final XFile? picked = await picker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1024,
    maxHeight: 1024,
  );
  if (picked == null) return null;

  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  final bytes = await picked.readAsBytes();
  final ext = _extensionOf(picked.name);
  final path = '$userId/avatar.$ext';

  await Supabase.instance.client.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
        ),
      );

  // The storage path is always the same for a given user, so without a
  // changing query string a previously-cached copy of it would keep
  // showing right after a fresh upload.
  final publicUrl =
      Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
  final bustedUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

  await Supabase.instance.client
      .from('profiles')
      .update({'avatar_url': bustedUrl}).eq('id', userId);

  return bustedUrl;
}

String _extensionOf(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot == -1 || dot == filename.length - 1) return 'jpg';
  final ext = filename.substring(dot + 1).toLowerCase();
  const allowed = {'jpg', 'jpeg', 'png', 'heic', 'webp'};
  return allowed.contains(ext) ? ext : 'jpg';
}

Future<ImageSource?> _askImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const Text(
            'Change profile photo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _SourceTile(
            icon: Icons.photo_library_outlined,
            label: 'Choose from gallery',
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
          _SourceTile(
            icon: Icons.camera_alt_outlined,
            label: 'Take a photo',
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
