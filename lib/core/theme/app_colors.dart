import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF1E293B); // Deep Indigo/Navy
  static const Color primaryLight = Color(0xFF334155);

  // Background & Surface
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;

  // Borders
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderDark = Color(0xFFCBD5E1); // Slate 300

  // Text
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textHint = Color(0xFF94A3B8); // Slate 400

  // Status Colors (Pastel Background, Dark Text)
  static const Color statusPendingBg = Color(0xFFFEF3C7); // Amber 50
  static const Color statusPendingText = Color(0xFFB45309); // Amber 700

  static const Color statusApprovedBg = Color(0xFFF3E8FF); // Purple 50
  static const Color statusApprovedText = Color(0xFF7E22CE); // Purple 700

  static const Color statusInProgressBg = Color(0xFFDBEAFE); // Blue 50
  static const Color statusInProgressText = Color(0xFF1D4ED8); // Blue 700

  static const Color statusCompletedBg = Color(0xFFD1FAE5); // Emerald 50
  static const Color statusCompletedText = Color(0xFF047857); // Emerald 700

  static const Color statusRejectedBg = Color(0xFFFEE2E2); // Red 50
  static const Color statusRejectedText = Color(0xFFB91C1C); // Red 700
}
