import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SharedPrefsService {
  static SharedPreferences? _preferences;

  // Keys
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserRole = 'user_role';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyRecentSearches = 'recent_searches';
  static const String _keyFavoriteRoutes = 'favorite_routes';
  static const String _keyLastSearchOrigin = 'last_search_origin';
  static const String _keyLastSearchDestination = 'last_search_destination';
  static const String _keyFirstTimeUser = 'first_time_user';
  static const String _keyAppVersion = 'app_version';

  // Initialize SharedPreferences (must be called before using any other methods)
  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  // Accessor for SharedPreferences instance with null check
  static SharedPreferences get instance {
    if (_preferences == null) {
      throw Exception('SharedPreferences not initialized. Call init() first.');
    }
    return _preferences!;
  }

  // ==================== User Session ====================

  static Future<bool> saveUserSession({
    required String userId,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) async {
    await instance.setBool(_keyIsLoggedIn, true);
    await instance.setString(_keyUserId, userId);
    await instance.setString(_keyUserEmail, email);
    await instance.setString(_keyUserName, name);
    await instance.setString(_keyUserPhone, phone);
    await instance.setString(_keyUserRole, role);
    return true;
  }

  static bool isLoggedIn() => instance.getBool(_keyIsLoggedIn) ?? false;

  static String? getUserId() => instance.getString(_keyUserId);

  static String? getUserEmail() => instance.getString(_keyUserEmail);

  static String? getUserName() => instance.getString(_keyUserName);

  static String? getUserPhone() => instance.getString(_keyUserPhone);

  static String? getUserRole() => instance.getString(_keyUserRole);

  static Future<bool> updateUserName(String name) => instance.setString(_keyUserName, name);

  static Future<bool> updateUserPhone(String phone) => instance.setString(_keyUserPhone, phone);

  static Future<bool> clearUserSession() async {
    await instance.remove(_keyIsLoggedIn);
    await instance.remove(_keyUserId);
    await instance.remove(_keyUserEmail);
    await instance.remove(_keyUserName);
    await instance.remove(_keyUserPhone);
    await instance.remove(_keyUserRole);
    return true;
  }

  // ==================== Remember Me ====================

  static Future<bool> setRememberMe(bool value) => instance.setBool(_keyRememberMe, value);

  static bool getRememberMe() => instance.getBool(_keyRememberMe) ?? false;

  // ==================== App Preferences ====================

  static Future<bool> setThemeMode(String mode) => instance.setString(_keyThemeMode, mode);

  static String getThemeMode() => instance.getString(_keyThemeMode) ?? 'system';

  static Future<bool> setNotificationsEnabled(bool enabled) => instance.setBool(_keyNotificationsEnabled, enabled);

  static bool getNotificationsEnabled() => instance.getBool(_keyNotificationsEnabled) ?? true;

  // ==================== Search History ====================

  /// Add a recent search as a string "origin|destination"
  static Future<bool> addRecentSearch(String origin, String destination) async {
    List<String> searches = instance.getStringList(_keyRecentSearches) ?? [];
    String searchString = '$origin|$destination';

    searches.remove(searchString); // Remove duplicate if exists
    searches.insert(0, searchString); // Add to beginning

    if (searches.length > 10) {
      searches = searches.sublist(0, 10);
    }

    return instance.setStringList(_keyRecentSearches, searches);
  }

  /// Get recent searches as List of Maps with keys 'origin' and 'destination'
  static List<Map<String, String>> getRecentSearches() {
    List<String> searches = instance.getStringList(_keyRecentSearches) ?? [];
    return searches.map((search) {
      List<String> parts = search.split('|');
      return {
        'origin': parts[0],
        'destination': parts.length > 1 ? parts[1] : '',
      };
    }).toList();
  }

  static Future<bool> clearRecentSearches() => instance.remove(_keyRecentSearches);

  // ==================== Favorite Routes ====================

  static Future<bool> addFavoriteRoute(String origin, String destination) async {
    List<String> favorites = instance.getStringList(_keyFavoriteRoutes) ?? [];
    String routeString = '$origin|$destination';

    if (!favorites.contains(routeString)) {
      favorites.add(routeString);
      return instance.setStringList(_keyFavoriteRoutes, favorites);
    }
    return false;
  }

  static Future<bool> removeFavoriteRoute(String origin, String destination) async {
    List<String> favorites = instance.getStringList(_keyFavoriteRoutes) ?? [];
    String routeString = '$origin|$destination';

    if (favorites.contains(routeString)) {
      favorites.remove(routeString);
      return instance.setStringList(_keyFavoriteRoutes, favorites);
    }
    return false;
  }

  static List<Map<String, String>> getFavoriteRoutes() {
    List<String> favorites = instance.getStringList(_keyFavoriteRoutes) ?? [];
    return favorites.map((route) {
      List<String> parts = route.split('|');
      return {
        'origin': parts[0],
        'destination': parts.length > 1 ? parts[1] : '',
      };
    }).toList();
  }

  static bool isFavoriteRoute(String origin, String destination) {
    List<String> favorites = instance.getStringList(_keyFavoriteRoutes) ?? [];
    String routeString = '$origin|$destination';
    return favorites.contains(routeString);
  }

  // ==================== Last Search ====================

  static Future<bool> saveLastSearch({required String origin, required String destination}) async {
    await instance.setString(_keyLastSearchOrigin, origin);
    await instance.setString(_keyLastSearchDestination, destination);
    return true;
  }

  static String? getLastSearchOrigin() => instance.getString(_keyLastSearchOrigin);

  static String? getLastSearchDestination() => instance.getString(_keyLastSearchDestination);

  // ==================== First Time User ====================

  static Future<bool> setFirstTimeUser(bool value) => instance.setBool(_keyFirstTimeUser, value);

  static bool isFirstTimeUser() => instance.getBool(_keyFirstTimeUser) ?? true;

  // ==================== App Version ====================

  static Future<bool> setAppVersion(String version) => instance.setString(_keyAppVersion, version);

  static String? getAppVersion() => instance.getString(_keyAppVersion);

  // ==================== Cache Management ====================

  /// Save cached data with optional expiry
  static Future<bool> setCachedData(String key, String data, {Duration? expiry}) async {
    await instance.setString('cache_$key', data);

    if (expiry != null) {
      int expiryTime = DateTime.now().add(expiry).millisecondsSinceEpoch;
      await instance.setInt('cache_${key}_expiry', expiryTime);
    }

    return true;
  }

  /// Get cached data, returns null if expired or not present
  static String? getCachedData(String key) {
    int? expiryTime = instance.getInt('cache_${key}_expiry');
    if (expiryTime != null && DateTime.now().millisecondsSinceEpoch > expiryTime) {
      // Cache expired
      removeCachedData(key);
      return null;
    }

    return instance.getString('cache_$key');
  }

  /// Remove cached data and expiry time
  static Future<bool> removeCachedData(String key) async {
    await instance.remove('cache_$key');
    await instance.remove('cache_${key}_expiry');
    return true;
  }

  /// Clear all cached entries (keys starting with 'cache_')
  static Future<bool> clearAllCache() async {
    final keys = instance.getKeys();
    for (String key in keys) {
      if (key.startsWith('cache_')) {
        await instance.remove(key);
      }
    }
    return true;
  }

  // ==================== Utility Methods ====================

  /// Clear all data from SharedPreferences
  static Future<bool> clearAll() => instance.clear();

  /// Check if a key exists
  static bool containsKey(String key) => instance.containsKey(key);

  /// Get all keys stored
  static Set<String> getAllKeys() => instance.getKeys();

  /// Print all stored key-value pairs (for debugging)
  static void printAllData() {
    final keys = instance.getKeys();
    print('=== SharedPreferences Data ===');
    for (var key in keys) {
      print('$key: ${instance.get(key)}');
    }
    print('==============================');
  }
}