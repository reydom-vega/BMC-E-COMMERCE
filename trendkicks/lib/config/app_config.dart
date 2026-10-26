class AppConfig {
  static const advancedShopping = bool.fromEnvironment('ADVANCED_SHOPPING');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const preview = bool.fromEnvironment('PREVIEW_MODE');
  static bool get isConfigured =>
      !preview && supabaseUrl.startsWith('https://') && supabaseKey.isNotEmpty;
}
