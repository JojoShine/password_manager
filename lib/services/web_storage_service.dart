import 'dart:convert';

import 'package:password_manager/models/password_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web平台的简单存储服务
/// 使用SharedPreferences存储数据
class WebStorageService {
  static const String _passwordEntriesKey = 'password_entries';

  static WebStorageService? _instance;
  static WebStorageService get instance => _instance ??= WebStorageService._();
  WebStorageService._();

  SharedPreferences? _prefs;
  bool _initialized = false;
  List<PasswordEntry> _memoryEntries = [];

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadPasswordEntries();
    } catch (e) {
      print('SharedPreferences初始化失败，使用内存存储: $e');
    }

    _initialized = true;
  }

  /// 从SharedPreferences加载密码条目
  Future<void> _loadPasswordEntries() async {
    try {
      final jsonString = _prefs?.getString(_passwordEntriesKey) ?? '[]';
      final List<dynamic> jsonList = json.decode(jsonString);
      _memoryEntries =
          jsonList.map((json) => PasswordEntry.fromMap(json)).toList();
    } catch (e) {
      print('加载密码条目失败: $e');
      _memoryEntries = [];
    }
  }

  /// 保存密码条目到SharedPreferences
  Future<void> _savePasswordEntries() async {
    try {
      final jsonString =
          json.encode(_memoryEntries.map((e) => e.toMap()).toList());
      await _prefs?.setString(_passwordEntriesKey, jsonString);
    } catch (e) {
      print('保存密码条目失败: $e');
    }
  }

  /// 获取所有密码条目
  Future<List<PasswordEntry>> getAllPasswordEntries() async {
    return List.from(_memoryEntries);
  }

  /// 添加新的密码条目
  Future<int> insertPasswordEntry(PasswordEntry entry) async {
    final newId = _memoryEntries.isEmpty
        ? 1
        : _memoryEntries.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) +
            1;

    final newEntry = PasswordEntry(
      id: newId,
      title: entry.title,
      username: entry.username,
      password: entry.password,
      website: entry.website,
      notes: entry.notes,
      customFields: entry.customFields,
      isFavorite: entry.isFavorite,
      category: entry.category,
      iconUrl: entry.iconUrl,
    );

    _memoryEntries.add(newEntry);
    await _savePasswordEntries();
    return newId;
  }

  /// 更新密码条目
  Future<int> updatePasswordEntry(PasswordEntry entry) async {
    final index = _memoryEntries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      _memoryEntries[index] = entry;
      await _savePasswordEntries();
      return 1;
    }
    return 0;
  }

  /// 删除密码条目
  Future<int> deletePasswordEntry(int id) async {
    final initialLength = _memoryEntries.length;
    _memoryEntries.removeWhere((e) => e.id == id);
    if (_memoryEntries.length < initialLength) {
      await _savePasswordEntries();
      return 1;
    }
    return 0;
  }

  /// 根据ID获取密码条目
  Future<PasswordEntry?> getPasswordEntry(int id) async {
    try {
      return _memoryEntries.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 搜索密码条目
  Future<List<PasswordEntry>> searchPasswordEntries(String query) async {
    if (query.isEmpty) return getAllPasswordEntries();

    final lowercaseQuery = query.toLowerCase();
    return _memoryEntries.where((entry) {
      return entry.title.toLowerCase().contains(lowercaseQuery) ||
          entry.username.toLowerCase().contains(lowercaseQuery) ||
          (entry.website?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          (entry.notes?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  /// 获取收藏的密码条目
  Future<List<PasswordEntry>> getFavoritePasswordEntries() async {
    return _memoryEntries.where((entry) => entry.isFavorite).toList();
  }

  /// 根据分类获取密码条目
  Future<List<PasswordEntry>> getPasswordEntriesByCategory(
      String category) async {
    return _memoryEntries.where((entry) => entry.category == category).toList();
  }

  /// 清空所有数据
  Future<void> clearAllData() async {
    _memoryEntries.clear();
    await _prefs?.remove(_passwordEntriesKey);
  }
}
