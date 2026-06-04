import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// Resolves text direction from script (Arabic, Farsi, Hebrew, etc.).
/// Returns null for empty text so the ambient direction applies.
TextDirection? textDirectionFor(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return intl.Bidi.detectRtlDirectionality(trimmed)
      ? TextDirection.rtl
      : TextDirection.ltr;
}
