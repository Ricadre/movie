import 'package:catmovie/shared/live_source_manage.dart';
import 'package:catmovie/app/modules/home/views/tv.dart' show Loader;
import 'package:flutter_test/flutter_test.dart';
import 'package:xi/xi.dart';

void main() {
  group('LiveSourceManage.parse', () {
    test('parses m3u and txt sources from a JSONC subscription', () {
      const subscription = r'''
      {
        // Video sources and live sources may share one subscription.
        "sites": [],
        "lives": [
          {
            "name": "电视直播",
            "url": "https://example.com/live",
            "type": 0
          },
          {
            "name": "备用直播",
            "url": "https://example.com/live.txt",
            "type": "txt"
          }
        ]
      }
      ''';

      final sources = LiveSourceManage.parse(subscription);

      expect(sources, hasLength(2));
      expect(sources.first.name, '电视直播');
      expect(sources.first.format, LiveSourceFormat.m3u);
      expect(sources.last.format, LiveSourceFormat.txt);
    });

    test('drops invalid entries and duplicate URLs', () {
      final sources = LiveSourceManage.parse({
        'lives': [
          {'name': 'A', 'url': 'https://example.com/a.m3u', 'type': 0},
          {'name': 'Duplicate', 'url': 'https://example.com/a.m3u', 'type': 1},
          {'name': '', 'url': 'https://example.com/invalid.m3u', 'type': 0},
          {'name': 'Missing URL', 'type': 0},
        ],
      });

      expect(sources, hasLength(1));
      expect(sources.single.name, 'A');
    });

    test('returns an empty list when lives is absent', () {
      expect(LiveSourceManage.parse({'sites': []}), isEmpty);
      expect(LiveSourceManage.parse('not json'), isEmpty);
    });
  });

  test('video source parser accepts the new sites root key', () {
    const subscription = r'''
    {
      "sites": [
        {
          "id": "cms-test",
          "name": "CMS Test",
          "type": 0,
          "api": "https://example.com/api.php/provide/vod/"
        }
      ],
      "lives": []
    }
    ''';

    final parsed = SourceUtils.tryParseDynamic(subscription);

    expect(parsed, isA<List>());
    expect(parsed as List, hasLength(1));
    expect(parsed.single, isA<MacCMSSpider>());
  });

  test('M3U parser keeps channel group, logo and URL', () {
    const playlist = '''#EXTM3U
#EXTINF:-1 tvg-id="1" tvg-logo="https://example.com/cctv.png" group-title="央视",CCTV-1
https://example.com/live/cctv1.m3u8
''';

    final groups = Loader.parseM3u(playlist);

    expect(groups.names, contains('央视'));
    expect(groups.tvs['央视']!.single.name, 'CCTV-1');
    expect(groups.tvs['央视']!.single.url, 'https://example.com/live/cctv1.m3u8');
  });

  test('TXT parser supports consecutive genre markers and URL commas', () {
    const playlist = '''央视,#genre#
CCTV-1,https://example.com/cctv1.m3u8?token=a,b
卫视,#genre#
湖南卫视,http://example.com/hunan.m3u8
''';

    final groups = Loader.parseTxt(playlist);

    expect(groups.names, ['央视', '卫视']);
    expect(groups.tvs['央视']!.single.url, contains('token=a,b'));
    expect(groups.tvs['卫视']!.single.name, '湖南卫视');
  });
}
