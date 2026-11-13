import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage.dart';

const _key = 'avatar_path_v1';

/// Local path of the user's profile photo (null → initials avatar).
class AvatarNotifier extends Notifier<String?> {
  @override
  String? build() {
    final p = ref.read(localStoreProvider).readString(_key);
    return p != null && File(p).existsSync() ? p : null;
  }

  /// Opens the gallery; returns false if nothing was picked.
  Future<bool> pick({ImageSource source = ImageSource.gallery}) async {
    final f = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (f == null) return false;
    final dir = await getApplicationDocumentsDirectory();
    final dest =
        '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(f.path).copy(dest);
    final old = state;
    state = dest;
    await ref.read(localStoreProvider).writeString(_key, dest);
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    return true;
  }

  Future<void> remove() async {
    state = null;
    await ref.read(localStoreProvider).remove(_key);
  }
}

final avatarProvider = NotifierProvider<AvatarNotifier, String?>(
  AvatarNotifier.new,
);
