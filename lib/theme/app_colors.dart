import 'package:flutter/material.dart';

/// HomeVault design system — v2 (modernized)
///
/// Design direction: "trusted home ledger" — a warm-neutral base with a
/// confident teal-navy primary (moves away from generic "default blue app"),
/// paired with an amber accent for warranty/attention states. Every color
/// has a light + dark variant so the app supports system theme switching.
class AppColors {
  AppColors._();

  // ---- Brand ----
  static const primary = Color(0xFF0F6E62); // deep teal — trust + "home"
  static const primaryLight = Color(0xFF4FA79A);
  static const secondary = Color(0xFF1B3A4B); // ink navy — depth, headers
  static const accent = Color(0xFFE9A23B); // warm amber — warranty/CTA highlights

  // ---- Semantic ----
  static const success = Color(0xFF2E9E5B);
  static const warning = Color(0xFFE9A23B);
  static const danger = Color(0xFFD64545);
  static const info = Color(0xFF3B82C4);

  // ---- Light surfaces ----
  static const backgroundLight = Color(0xFFF7F5F0); // warm off-white, not clinical gray
  static const cardLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFEFEAE1);
  static const textPrimaryLight = Color(0xFF1C1B1A);
  static const textSecondaryLight = Color(0xFF6B6660);

  // ---- Dark surfaces ----
  static const backgroundDark = Color(0xFF13181A);
  static const cardDark = Color(0xFF1C2226);
  static const surfaceAltDark = Color(0xFF232B2F);
  static const textPrimaryDark = Color(0xFFF2F0EC);
  static const textSecondaryDark = Color(0xFFA6ADAF);

  // ---- Gradients (used on dashboard hero / stat cards) ----
  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F6E62), Color(0xFF1B3A4B)],
  );

  static const gradientWarm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9A23B), Color(0xFFD9782E)],
  );
}