import 'dart:convert';

/// 密码条目模型
class PasswordEntry {
  final int? id;
  final String title;
  final String username;
  final String password;
  final String? website;
  final String? notes;
  final Map<String, dynamic> customFields; // 自定义字段
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final String? category;
  final String? iconUrl;

  PasswordEntry({
    this.id,
    required this.title,
    required this.username,
    required this.password,
    this.website,
    this.notes,
    this.customFields = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
    this.category,
    this.iconUrl,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从数据库Map创建PasswordEntry实例
  factory PasswordEntry.fromMap(Map<String, dynamic> map) {
    return PasswordEntry(
      id: map['id'] as int?,
      title: map['title'] as String,
      username: map['username'] as String,
      password: map['password'] as String,
      website: map['website'] as String?,
      notes: map['notes'] as String?,
      customFields: map['custom_fields'] != null
          ? Map<String, dynamic>.from(
              jsonDecode(map['custom_fields'] as String))
          : {},
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isFavorite: (map['is_favorite'] as int) == 1,
      category: map['category'] as String?,
      iconUrl: map['icon_url'] as String?,
    );
  }

  /// 从JSON创建PasswordEntry实例
  factory PasswordEntry.fromJson(Map<String, dynamic> json) {
    return PasswordEntry(
      id: json['id'] as int?,
      title: json['title'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      website: json['website'] as String?,
      notes: json['notes'] as String?,
      customFields: json['customFields'] != null
          ? Map<String, dynamic>.from(json['customFields'] as Map)
          : {},
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
      category: json['category'] as String?,
      iconUrl: json['iconUrl'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'username': username,
      'password': password,
      'website': website,
      'notes': notes,
      'customFields': customFields,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFavorite': isFavorite,
      'category': category,
      'iconUrl': iconUrl,
    };
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'username': username,
      'password': password,
      'website': website,
      'notes': notes,
      'custom_fields': jsonEncode(customFields),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
      'category': category,
      'icon_url': iconUrl,
    };
  }

  /// 创建副本并更新某些字段
  PasswordEntry copyWith({
    int? id,
    String? title,
    String? username,
    String? password,
    String? website,
    String? notes,
    Map<String, dynamic>? customFields,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    String? category,
    String? iconUrl,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }

  /// 添加或更新自定义字段
  PasswordEntry addCustomField(String key, dynamic value) {
    final newCustomFields = Map<String, dynamic>.from(customFields);
    newCustomFields[key] = value;
    return copyWith(customFields: newCustomFields);
  }

  /// 移除自定义字段
  PasswordEntry removeCustomField(String key) {
    final newCustomFields = Map<String, dynamic>.from(customFields);
    newCustomFields.remove(key);
    return copyWith(customFields: newCustomFields);
  }

  @override
  String toString() {
    return 'PasswordEntry{id: $id, title: $title, username: $username, website: $website, customFields: $customFields}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PasswordEntry &&
        other.id == id &&
        other.title == title &&
        other.username == username &&
        other.password == password &&
        other.website == website &&
        other.notes == notes &&
        other.customFields.toString() == customFields.toString() &&
        other.isFavorite == isFavorite &&
        other.category == category;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      username,
      password,
      website,
      notes,
      customFields.toString(),
      isFavorite,
      category,
    );
  }
}
