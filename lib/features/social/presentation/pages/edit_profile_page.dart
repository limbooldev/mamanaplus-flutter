import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../chat/data/chat_repository.dart';
import '../../data/social_repository.dart';
import '../widgets/social_media_widgets.dart';

/// Edit display name, bio, and profile photo for the signed-in user.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String? _avatarKey;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await context.read<ChatRepository>().fetchMe();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = (me['display_name'] as String?)?.trim() ?? '';
        _bioCtrl.text = (me['bio'] as String?)?.trim() ?? '';
        final k = me['avatar_media_key'] as String?;
        _avatarKey = (k != null && k.isNotEmpty) ? k : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    final messenger = ScaffoldMessenger.of(context);
    final social = context.read<SocialRepository>();
    try {
      final bytes = await File(x.path).readAsBytes();
      final ct = lookupMimeType(x.path) ?? 'image/jpeg';
      final key = await social.uploadSocialMediaBytes(bytes, ct);
      if (!mounted) return;
      setState(() {
        _avatarKey = key;
        _uploadingPhoto = false;
      });
      await social.patchMe(avatarMediaKey: key);
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      if (mounted) setState(() => _uploadingPhoto = false);
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final social = context.read<SocialRepository>();
    try {
      await social.patchMe(
        displayName: name,
        bio: _bioCtrl.text.trim(),
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
      Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: SizedBox(
              width: 108,
              height: 108,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: _avatarKey != null && _avatarKey!.isNotEmpty
                          ? SocialPostImage(mediaRef: _avatarKey, fit: BoxFit.cover)
                          : ColoredBox(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.person,
                                size: 48,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                    ),
                  ),
                  if (_uploadingPhoto)
                    Positioned.fill(
                      child: ClipOval(
                        child: ColoredBox(
                          color: Colors.black38,
                          child: Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: IconButton.filledTonal(
                      onPressed: _uploadingPhoto ? null : _pickPhoto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioCtrl,
            decoration: const InputDecoration(
              labelText: 'Bio',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          Text(
            'Photos use the same secure upload as community posts.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
