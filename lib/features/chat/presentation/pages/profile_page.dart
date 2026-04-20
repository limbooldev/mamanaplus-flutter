import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/jwt_util.dart';
import '../../../../shared/ui/ui.dart';
import '../../../social/data/social_repository.dart';
import '../../../social/presentation/pages/edit_profile_page.dart';
import '../../../social/presentation/pages/social_user_list_page.dart';
import '../../../social/presentation/pages/user_profile_page.dart';
import '../../data/chat_repository.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/theme_cubit.dart';

// Decodes the JWT payload into a map for display purposes only (no verification).
// Used as the immediate/fallback value before the /me response arrives.
Map<String, dynamic> _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    var payload = parts[1];
    final mod = payload.length % 4;
    if (mod > 0) payload += '=' * (4 - mod);
    final json = utf8.decode(base64Url.decode(payload));
    return jsonDecode(json) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Holds the result of GET /v1/me once it resolves.
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await context.read<ChatRepository>().fetchMe();
      if (mounted) setState(() => _profile = data);
    } catch (_) {
      // Silent — JWT claims are used as the fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use /me data when available; fall back to JWT claims decoded locally.
    final authState = context.watch<AuthCubit>().state;
    final Map<String, dynamic> claims =
        authState is AuthAuthenticated ? _decodeJwtPayload(authState.accessToken) : {};
    final source = _profile ?? claims;

    final displayName = (source['display_name'] as String?)?.trim() ?? '';
    final email = (source['email'] as String?)?.trim() ?? '';
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');
    final myId = (source['id'] as num?)?.toInt() ??
        (authState is AuthAuthenticated
            ? parseUserIdFromAccessToken(authState.accessToken)
            : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        children: [
          // ── Avatar + name card ──────────────────────────────────────────
          _ProfileHeader(
            initials: initials,
            displayName: displayName,
            email: email,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          if (myId != null) ...[
            ListTile(
              leading: const Icon(Icons.person_outlined),
              title: const Text('My profile'),
              subtitle: const Text('Posts, followers, bio'),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => UserProfilePage(userId: myId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit profile'),
              subtitle: const Text('Name, bio, photo'),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const EditProfilePage()),
                );
                if (context.mounted) _loadProfile();
              },
            ),
            const Divider(height: 1),
          ],
          // ── Appearance ──────────────────────────────────────────────────
          _SectionHeader(title: 'Appearance'),
          const _ThemeSelector(),
          const Divider(height: 1),
          // ── Social ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Community'),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('Hidden profiles'),
            subtitle: const Text('Users hidden from your feed'),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => RepositoryProvider.value(
                    value: context.read<SocialRepository>(),
                    child: SocialUserListPage(
                      title: 'Hidden profiles',
                      load: (r, p) => r.hiddenUsers(page: p),
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.trending_up_outlined),
            title: const Text('Top members'),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => RepositoryProvider.value(
                    value: context.read<SocialRepository>(),
                    child: SocialUserListPage(
                      title: 'Top members',
                      load: (r, p) => r.discoveryTop(page: p),
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: const Text('Newest members'),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => RepositoryProvider.value(
                    value: context.read<SocialRepository>(),
                    child: SocialUserListPage(
                      title: 'Newest members',
                      load: (r, p) => r.discoveryLatest(page: p),
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: const Text('Add story media'),
            subtitle: const Text('Paste image URL after upload'),
            onTap: () async {
              final ctrl = TextEditingController();
              final url = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Story image URL'),
                  content: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      hintText: 'https://…',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              );
              if (url != null &&
                  url.isNotEmpty &&
                  context.mounted) {
                try {
                  await context.read<SocialRepository>().addStoryMedia(url);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Story media added')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              }
            },
          ),
          if (source['is_super_admin'] == true) ...[
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Approve user profile'),
              subtitle: const Text('Admin — enter user id'),
              onTap: () async {
                final ctrl = TextEditingController();
                final idStr = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('User id to approve'),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(ctx, ctrl.text.trim()),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                );
                final uid = int.tryParse(idStr ?? '');
                if (uid != null && context.mounted) {
                  try {
                    await context
                        .read<SocialRepository>()
                        .approveUserProfile(uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User approved')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                }
              },
            ),
          ],
          const Divider(height: 1),
          // ── Account ─────────────────────────────────────────────────────
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.logout_outlined, color: AppColors.error),
            title: Text(
              'Sign out',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.error,
              ),
            ),
            onTap: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.displayName,
    required this.email,
  });

  final String initials;
  final String displayName;
  final String email;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (displayName.isNotEmpty)
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.onBackgroundDark
                          : AppColors.onBackgroundLight,
                    ),
                  ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.subtitleLight,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.subtitleLight,
        ),
      ),
    );
  }
}

// ─── Theme selector ───────────────────────────────────────────────────────────

const _themeModeLabels = {
  ThemeMode.system: 'System default',
  ThemeMode.light: 'Light',
  ThemeMode.dark: 'Dark',
};

const _themeModeIcons = {
  ThemeMode.system: Icons.phone_android_outlined,
  ThemeMode.light: Icons.light_mode_outlined,
  ThemeMode.dark: Icons.dark_mode_outlined,
};

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final currentMode = context.watch<ThemeCubit>().state;

    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined, color: AppColors.subtitleLight),
      title: Text(
        'Theme',
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<ThemeMode>(
          value: currentMode,
          borderRadius: BorderRadius.circular(12),
          items: ThemeMode.values.map((mode) {
            return DropdownMenuItem(
              value: mode,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_themeModeIcons[mode], size: 18, color: AppColors.subtitleLight),
                  const SizedBox(width: 8),
                  Text(
                    _themeModeLabels[mode]!,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (mode) {
            if (mode != null) context.read<ThemeCubit>().setTheme(mode);
          },
        ),
      ),
    );
  }
}
