import 'package:flutter/foundation.dart';

import '../auth/tz_phone.dart';
import '../locale/nj_locale.dart';

/// A signed-in user's account record.
///
/// Created by the `handle_new_user` trigger the moment a phone number is
/// verified, so no screen has to handle "signed in but has no profile".
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.phone,
    required this.lang,
    this.displayName,
    this.createdAt,
  });

  /// Builds a profile from a `profiles` row.
  ///
  /// Tolerant of a missing or unknown language: the column is constrained to
  /// `sw` or `en`, but a row written before a future language is added should
  /// still load rather than crashing a returning user out of the app.
  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        id: row['id'] as String,
        phone: TzPhone.tryParse(row['phone'] as String?),
        lang: NjLocale.tryParse(row['lang'] as String?) ?? NjLocale.fallback,
        displayName: row['display_name'] as String?,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      );

  /// The auth user id.
  final String id;

  /// The verified number, or null if it could not be parsed.
  final TzPhone? phone;

  /// The account's language. What SMS and push notifications are written in.
  final NjLocale lang;

  /// Set during driver sign-up at C6. Passengers do not need one.
  final String? displayName;

  /// When the account was created.
  final DateTime? createdAt;

  Profile copyWith({NjLocale? lang, String? displayName}) => Profile(
        id: id,
        phone: phone,
        lang: lang ?? this.lang,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.phone == phone &&
      other.lang == lang &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, phone, lang, displayName);

  @override
  String toString() => 'Profile($id, ${phone?.national}, ${lang.code})';
}
