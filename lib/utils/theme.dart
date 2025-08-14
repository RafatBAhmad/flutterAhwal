import 'package:flutter/material.dart';

class AppTheme {
  // 🔥 ألوان مستوحاة من الصورة المرفقة
  static const Color primaryPurple = Color(0xFF9C4DCC); // البنفسجي الأساسي من الصورة
  static const Color lightPurple = Color(0xFFE1BEE7);   // بنفسجي فاتح
  static const Color darkPurple = Color(0xFF7B1FA2);    // بنفسجي غامق
  static const Color accentOrange = Color(0xFFFF5722);  // البرتقالي من السيارة
  static const Color surfaceLight = Color(0xFFFAF8FF);  // خلفية فاتحة بلمسة بنفسجية
  static const Color cardLight = Color(0xFFFFFFFF);     // لون الكروت

  // ألوان الحالات المحسنة
  static const Color statusOpen = Color(0xFF4CAF50);    // أخضر للسالك
  static const Color statusClosed = Color(0xFFF44336);  // أحمر للمغلق
  static const Color statusCongestion = Color(0xFFFF9800); // برتقالي للازدحام

  // Theme النهاري المحسن
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: primaryPurple,
      primaryContainer: lightPurple,
      onPrimaryContainer: darkPurple,
      secondary: accentOrange,
      secondaryContainer: Color(0xFFFFE0B2),
      onSecondaryContainer: Color(0xFFE65100),
      surface: surfaceLight,
      onSurface: Color(0xFF1A1A1A),
      error: statusClosed,
      onError: Colors.white,
      outline: Color(0xFFE0E0E0),
      outlineVariant: Color(0xFFF5F5F5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto', // يمكن تغييرها لخط عربي

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 2,
        shadowColor: primaryPurple.withValues(alpha: (0.2)),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkPurple,
        ),
        iconTheme: const IconThemeData(
          color: darkPurple,
          size: 24,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 3,
        shadowColor: primaryPurple.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: primaryPurple.withValues(alpha: (0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPurple,
          side: const BorderSide(color: primaryPurple),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // FloatingActionButton Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: lightPurple.withValues(alpha: (0.3)),
        selectedColor: primaryPurple.withValues(alpha: (0.2)),
        checkmarkColor: primaryPurple,
        labelStyle: const TextStyle(
          color: darkPurple,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: primaryPurple),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryPurple,
        unselectedItemColor: Colors.grey[600],
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: primaryPurple.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkPurple,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: lightPurple,
        iconColor: primaryPurple,
        textColor: Color(0xFF1A1A1A),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryPurple,
        linearTrackColor: lightPurple,
        circularTrackColor: lightPurple,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryPurple;
          }
          return Colors.grey[400];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryPurple.withValues(alpha: 0.5);
          }
          return Colors.grey[300];
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryPurple;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: primaryPurple),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryPurple;
          }
          return Colors.grey[600];
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryPurple,
        inactiveTrackColor: lightPurple,
        thumbColor: primaryPurple,
        overlayColor: primaryPurple.withValues(alpha: 0.2),
        valueIndicatorColor: primaryPurple,
      ),

      // Tab Bar Theme
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryPurple,
        unselectedLabelColor: Colors.grey,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primaryPurple, width: 2),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: primaryPurple,
        size: 24,
      ),

      // Primary Icon Theme
      primaryIconTheme: const IconThemeData(
        color: Colors.white,
        size: 24,
      ),

      // Text Theme محسن للعربية
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: Color(0xFF1A1A1A),
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: Color(0xFF1A1A1A),
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: Color(0xFF1A1A1A),
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: darkPurple,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkPurple,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkPurple,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFF1A1A1A),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF1A1A1A),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF666666),
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: primaryPurple,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: primaryPurple,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF666666),
        ),
      ),
    );
  }

  // Theme الداكن المحسن
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFFE1BEE7),           // بنفسجي فاتح للعناصر الرئيسية
      primaryContainer: Color(0xFF4A148C),   // بنفسجي غامق للحاويات
      onPrimaryContainer: Color(0xFFE1BEE7), // نص على الحاويات
      secondary: Color(0xFFFF7043),          // برتقالي محسن
      secondaryContainer: Color(0xFF3E2723), // بني غامق
      onSecondaryContainer: Color(0xFFFFCC80),
      surface: Color(0xFF1E1E1E),            // خلفية رمادية داكنة محسنة
      onSurface: Color(0xFFE0E0E0),          // نص أبيض مخفف
      surfaceContainerHighest: Color(0xFF2A2A2A), // للكروت
      error: Color(0xFFEF5350),
      onError: Color(0xFF000000),
      outline: Color(0xFF525252),            // حدود محسنة
      outlineVariant: Color(0xFF3A3A3A),
      inverseSurface: Color(0xFFE0E0E0),
      onInverseSurface: Color(0xFF1E1E1E),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,

      // AppBar Theme محسن
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.black45,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE0E0E0),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFE1BEE7),
          size: 24,
        ),
      ),

      // Card Theme محسن
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 4,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.primaryContainer,
          elevation: 3,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input Decoration Theme محسن
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // FloatingActionButton Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.primaryContainer,
        elevation: 6,
        shape: const CircleBorder(),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
        checkmarkColor: colorScheme.primary,
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.6),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 8,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.2),
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.outline,
        circularTrackColor: colorScheme.outline,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.5);
          }
          return colorScheme.surface;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.primaryContainer),
        side: BorderSide(color: colorScheme.primary),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurface.withValues(alpha: 0.6);
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.outline,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.2),
        valueIndicatorColor: colorScheme.primary,
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.7),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
      ),

      // Primary Icon Theme
      primaryIconTheme: IconThemeData(
        color: colorScheme.primary,
        size: 24,
      ),

      // Text Theme محسن للعربية
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.primary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.primary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  // دوال مساعدة للألوان

  /// الحصول على لون الحالة
  static Color getStatusColor(String status, {Map<String, int>? customColors}) {
    if (customColors != null) {
      switch (status.toLowerCase()) {
        case 'مفتوح':
        case 'سالكة':
        case 'سالكه':
        case 'سالك':
          return Color(customColors['openColor'] ?? statusOpen.value);
        case 'مغلق':
          return Color(customColors['closedColor'] ?? statusClosed.value);
        case 'ازدحام':
          return Color(customColors['congestionColor'] ?? statusCongestion.value);
        default:
          return Colors.grey;
      }
    }
    
    switch (status.toLowerCase()) {
      case 'مفتوح':
      case 'سالكة':
      case 'سالكه':
      case 'سالك':
        return statusOpen;
      case 'مغلق':
        return statusClosed;
      case 'ازدحام':
        return statusCongestion;
      default:
        return Colors.grey;
    }
  }

  /// الحصول على أيقونة الحالة
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'مفتوح':
      case 'سالكة':
      case 'سالكه':
      case 'سالك':
        return Icons.check_circle;
      case 'مغلق':
        return Icons.cancel;
      case 'ازدحام':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  /// الحصول على لون مناسب للخلفية
  static Color getStatusBackgroundColor(String status, bool isDark, {Map<String, int>? customColors}) {
    final statusColor = getStatusColor(status, customColors: customColors);
    return statusColor.withValues(alpha: isDark ? 0.2 : 0.1);
  }

  /// الحصول على لون الحدود
  static Color getStatusBorderColor(String status, bool isDark, {Map<String, int>? customColors}) {
    final statusColor = getStatusColor(status, customColors: customColors);
    return statusColor.withValues(alpha: isDark ? 0.4 : 0.3);
  }

  // تدرجات لونية مخصصة

  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [primaryPurple, lightPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get cardGradient => LinearGradient(
    colors: [
      Colors.white,
      primaryPurple.withValues(alpha: (0.02)),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient statusGradient(String status) {
    final color = getStatusColor(status);
    return LinearGradient(
      colors: [
        color.withValues(alpha: (0.1)),
        color.withValues(alpha: (0.05)),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // أنماط نصوص مخصصة

  static TextStyle get checkpointNameStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1A1A1A),
  );

  static TextStyle get checkpointStatusStyle => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get timestampStyle => TextStyle(
    fontSize: 11,
    color: Colors.grey[600],
    fontWeight: FontWeight.w400,
  );

  static TextStyle get cityNameStyle => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: darkPurple,
  );

  // أنماط الكونتينرات

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardLight,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: primaryPurple.withValues(alpha: 0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration statusContainerDecoration(String status, {Map<String, int>? customColors}) => BoxDecoration(
    color: getStatusBackgroundColor(status, false, customColors: customColors),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: getStatusBorderColor(status, false, customColors: customColors),
      width: 1,
    ),
  );

  static BoxDecoration get searchBarDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: primaryPurple.withValues(alpha: 0.2),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: primaryPurple.withValues(alpha: 0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // أنماط التحديد والفلترة

  static BoxDecoration get selectedFilterDecoration => BoxDecoration(
    color: primaryPurple.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: primaryPurple, width: 2),
  );

  static BoxDecoration get unselectedFilterDecoration => BoxDecoration(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: primaryPurple.withValues(alpha: 0.5), width: 1),
  );

  // أنماط الإشعارات والرسائل الجديدة

  static BoxDecoration get newMessageDecoration => BoxDecoration(
    color: lightPurple.withValues(alpha: 0.3),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: primaryPurple, width: 1),
    boxShadow: [
      BoxShadow(
        color: primaryPurple.withValues(alpha: 0.2),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get notificationBadgeDecoration => const BoxDecoration(
    color: statusClosed,
    shape: BoxShape.circle,
  );

  // ثوابت التخطيط

  static const double cardMargin = 12.0;
  static const double cardPaddingValue = 16.0;
  static const double borderRadius = 12.0;
  static const double iconSize = 24.0;
  static const double smallIconSize = 20.0;
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;

  // ثوابت المسافات

  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  // دالة للحصول على Theme حسب الوضع
  static ThemeData getTheme(bool isDark) {
    return isDark ? darkTheme : lightTheme;
  }

  // دالة للحصول على الألوان حسب الوضع
  static ColorScheme getColorScheme(bool isDark) {
    return isDark ? darkTheme.colorScheme : lightTheme.colorScheme;
  }
}