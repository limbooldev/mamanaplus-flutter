// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MamanaPlus';

  @override
  String get labelEmail => 'Email';

  @override
  String get labelPassword => 'Password (min 8)';

  @override
  String get labelDisplayName => 'Display name';

  @override
  String get buttonLogin => 'Login';

  @override
  String get buttonRegister => 'Register';

  @override
  String get toggleToLogin => 'Have an account? Login';

  @override
  String get toggleToRegister => 'Create account';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get dmDialogTitle => 'Open DM with user id';

  @override
  String get dmPeerHint => 'Peer user id';

  @override
  String get buttonCancel => 'Cancel';

  @override
  String get buttonOpen => 'Open';

  @override
  String get chatFallback => 'Chat';

  @override
  String chatFallbackId(int id) {
    return 'Chat #$id';
  }

  @override
  String get newGroupTitle => 'New group';

  @override
  String get labelGroupTitle => 'Group title';

  @override
  String get labelMemberIds => 'Member user ids (comma-separated)';

  @override
  String get buttonCreate => 'Create';

  @override
  String get groupAppBarTitle => 'Group';

  @override
  String groupFallbackTitle(int id) {
    return 'Group #$id';
  }

  @override
  String userFallback(String id) {
    return 'User $id';
  }

  @override
  String threadTitle(int id) {
    return 'Thread #$id';
  }

  @override
  String replyingTo(String message) {
    return 'Replying to: $message';
  }

  @override
  String get userNameYou => 'You';

  @override
  String get typingIndicator => 'Someone is typing…';

  @override
  String get composerHint => 'Message';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDeleteForMe => 'Delete for me';

  @override
  String get actionDeleteForEveryone => 'Delete for everyone';

  @override
  String get editMessageTitle => 'Edit message';

  @override
  String get buttonSave => 'Save';

  @override
  String get blockDialogTitle => 'Block user id';

  @override
  String get buttonBlock => 'Block';

  @override
  String get snackBlocked => 'Blocked';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabGroups => 'Groups';

  @override
  String get noPublicGroups => 'No public groups yet';

  @override
  String membersCount(int count) {
    return '$count members';
  }

  @override
  String get buttonJoin => 'Join';

  @override
  String get joinFailed => 'Failed to join group';

  @override
  String get imageEditorUndo => 'Undo';

  @override
  String get imageEditorRedo => 'Redo';

  @override
  String get imageEditorDone => 'Done';

  @override
  String get imageEditorApplyingChanges => 'Applying changes…';

  @override
  String videoEditorExportFailed(String error) {
    return 'Could not export video: $error';
  }

  @override
  String get pickUsersTitleSingle => 'New message';

  @override
  String get pickUsersTitleMulti => 'Add members';

  @override
  String get pickUsersSearchHint => 'Search by name';

  @override
  String get pickUsersSectionFromChats => 'From your chats';

  @override
  String get pickUsersSectionEveryone => 'Everyone';

  @override
  String get pickUsersEmptyRemote => 'No matching people on the server';

  @override
  String get pickUsersMinCharsForDirectory =>
      'Type at least 2 characters to search everyone';

  @override
  String get pickUsersEmpty => 'No people match your search';

  @override
  String get pickUsersNoDirectChats =>
      'No direct chats yet. Search below to find someone.';

  @override
  String get pickUsersSearchFailed => 'Search failed. Try again.';

  @override
  String get pickUsersDone => 'Done';

  @override
  String get labelAddMembers => 'Members';

  @override
  String membersSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members selected',
      one: '1 member selected',
      zero: 'No members selected',
    );
    return '$_temp0';
  }
}
