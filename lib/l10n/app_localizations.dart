import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MamanaPlus'**
  String get appTitle;

  /// No description provided for @labelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get labelEmail;

  /// No description provided for @labelPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (min 8)'**
  String get labelPassword;

  /// No description provided for @labelDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get labelDisplayName;

  /// No description provided for @buttonLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get buttonLogin;

  /// No description provided for @buttonRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get buttonRegister;

  /// No description provided for @toggleToLogin.
  ///
  /// In en, this message translates to:
  /// **'Have an account? Login'**
  String get toggleToLogin;

  /// No description provided for @toggleToRegister.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get toggleToRegister;

  /// No description provided for @chatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// No description provided for @dmDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Open DM with user id'**
  String get dmDialogTitle;

  /// No description provided for @dmPeerHint.
  ///
  /// In en, this message translates to:
  /// **'Peer user id'**
  String get dmPeerHint;

  /// No description provided for @buttonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buttonCancel;

  /// No description provided for @buttonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get buttonOpen;

  /// No description provided for @chatFallback.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatFallback;

  /// No description provided for @chatFallbackId.
  ///
  /// In en, this message translates to:
  /// **'Chat #{id}'**
  String chatFallbackId(int id);

  /// No description provided for @newGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroupTitle;

  /// No description provided for @labelGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Group title'**
  String get labelGroupTitle;

  /// No description provided for @labelMemberIds.
  ///
  /// In en, this message translates to:
  /// **'Member user ids (comma-separated)'**
  String get labelMemberIds;

  /// No description provided for @buttonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get buttonCreate;

  /// No description provided for @groupAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupAppBarTitle;

  /// No description provided for @groupFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Group #{id}'**
  String groupFallbackTitle(int id);

  /// No description provided for @userFallback.
  ///
  /// In en, this message translates to:
  /// **'User {id}'**
  String userFallback(String id);

  /// No description provided for @threadTitle.
  ///
  /// In en, this message translates to:
  /// **'Thread #{id}'**
  String threadTitle(int id);

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to: {message}'**
  String replyingTo(String message);

  /// No description provided for @userNameYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get userNameYou;

  /// No description provided for @typingIndicator.
  ///
  /// In en, this message translates to:
  /// **'Someone is typing…'**
  String get typingIndicator;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get composerHint;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDeleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get actionDeleteForMe;

  /// No description provided for @actionDeleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get actionDeleteForEveryone;

  /// No description provided for @editMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessageTitle;

  /// No description provided for @buttonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get buttonSave;

  /// No description provided for @blockDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Block user id'**
  String get blockDialogTitle;

  /// No description provided for @buttonBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get buttonBlock;

  /// No description provided for @snackBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get snackBlocked;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
