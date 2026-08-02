import 'dart:convert';

import 'package:crypto/crypto.dart';

String securityScopeKey(String uid) {
  final normalized = uid.trim();
  if (normalized.isEmpty) {
    throw const FormatException('A user ID is required for secure storage.');
  }

  return sha256.convert(utf8.encode(normalized)).toString().substring(0, 20);
}
