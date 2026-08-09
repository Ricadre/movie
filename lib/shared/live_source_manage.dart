import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xi/xi.dart';

enum LiveSourceFormat { m3u, txt }

@immutable
class LiveSourceConfig {
  const LiveSourceConfig({
    required this.name,
    required this.url,
    required this.format,
  });

  final String name;
  final String url;
  final LiveSourceFormat format;

  static LiveSourceConfig? fromJson(Map<String, dynamic> data) {
    final name = data['name']?.toString().trim() ?? '';
    final url = data['url']?.toString().trim() ?? '';
    if (name.isEmpty || url.isEmpty) return null;

    final rawType = data['type'];
    final normalizedType = rawType?.toString().trim().toLowerCase();
    final format = normalizedType == '1' || normalizedType == 'txt'
        ? LiveSourceFormat.txt
        : LiveSourceFormat.m3u;

    return LiveSourceConfig(name: name, url: url, format: format);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'type': format == LiveSourceFormat.m3u ? 0 : 1,
  };
}

/// Stores the dynamic IPTV sources imported from subscription files.
///
/// Movie 2.5.9 already contains the player and M3U/TXT parsers, but its source
/// list is hard-coded in the TV page. This store supplies the missing dynamic
/// `lives` portion of the >=2.6 subscription format without changing the Isar
/// database schema.
class LiveSourceManage {
  LiveSourceManage._();

  static const _filename = 'live_sources.json';
  static List<LiveSourceConfig> _sources = const [];

  /// Notifies an already-mounted TV page after a subscription refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static List<LiveSourceConfig> get sources => List.unmodifiable(_sources);

  static Future<File> _storageFile() async {
    final directory = await getApplicationSupportDirectory();
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$_filename');
  }

  static Future<void> init() async {
    try {
      final file = await _storageFile();
      if (!file.existsSync()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return;
      _sources = _deduplicate(
        decoded
            .whereType<Map>()
            .map(
              (item) =>
                  LiveSourceConfig.fromJson(Map<String, dynamic>.from(item)),
            )
            .whereType<LiveSourceConfig>()
            .toList(),
      );
    } catch (error) {
      debugPrint('读取直播源配置失败: $error');
      _sources = const [];
    }
  }

  /// Extracts `lives` from a decoded object or a JSON/JSONC string.
  static List<LiveSourceConfig> parse(dynamic rawData) {
    try {
      dynamic decoded = rawData;
      if (decoded is String) {
        if (decoded.trim().isEmpty) return const [];
        decoded = jsonc.decode(decoded);
      }
      if (decoded is! Map) return const [];

      final root = Map<String, dynamic>.from(decoded);
      final lives = root['lives'];
      if (lives is! List) return const [];

      return _deduplicate(
        lives
            .whereType<Map>()
            .map(
              (item) =>
                  LiveSourceConfig.fromJson(Map<String, dynamic>.from(item)),
            )
            .whereType<LiveSourceConfig>()
            .toList(),
      );
    } catch (error) {
      debugPrint('解析直播源配置失败: $error');
      return const [];
    }
  }

  static Future<void> replace(Iterable<LiveSourceConfig> sources) async {
    _sources = _deduplicate(sources);
    await _save();
  }

  static Future<void> merge(Iterable<LiveSourceConfig> sources) async {
    _sources = _deduplicate([..._sources, ...sources]);
    await _save();
  }

  static List<LiveSourceConfig> _deduplicate(
    Iterable<LiveSourceConfig?> sources,
  ) {
    final result = <LiveSourceConfig>[];
    final seen = <String>{};
    for (final source in sources.whereType<LiveSourceConfig>()) {
      if (seen.add(source.url)) result.add(source);
    }
    return result;
  }

  static Future<void> _save() async {
    final file = await _storageFile();
    await file.writeAsString(
      jsonEncode(_sources.map((item) => item.toJson()).toList()),
      flush: true,
    );
    revision.value++;
  }
}
