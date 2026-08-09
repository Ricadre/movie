library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Kept compatible with the enum persisted by CatMovie 2.5.9.
enum IWebPlayerEmbeddedType { p2pHLS }

class WebPlayerMessage {
  const WebPlayerMessage({required this.type, required this.value});

  final String type;
  final String value;
}

/// A small, dependency-free replacement for the deleted upstream package.
///
/// CatMovie only uses this helper for its desktop external-WebView player. iOS
/// playback uses media-kit directly, but retaining this API keeps every target
/// compilable from a fresh checkout.
class WebPlayerEmbedded {
  HttpServer? _server;
  void Function(WebPlayerMessage message)? _onMessage;

  Future<bool> checkRunning() async => _server != null;

  Future<HttpServer> createServer({
    void Function(WebPlayerMessage message)? onMessage,
  }) async {
    await dispose();
    _onMessage = onMessage;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(_serve(server));
    return server;
  }

  String generatePlayerUrl(IWebPlayerEmbeddedType type, String mediaUrl) {
    final server = _server;
    if (server == null) return mediaUrl;
    final encoded = Uri.encodeQueryComponent(mediaUrl);
    return 'http://localhost:${server.port}/player.html?url=$encoded';
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        if (request.method == 'POST' && request.uri.path == '/message') {
          final body = await utf8.decoder.bind(request).join();
          final data = jsonDecode(body);
          if (data is Map) {
            _onMessage?.call(
              WebPlayerMessage(
                type: data['type']?.toString() ?? '',
                value: data['value']?.toString() ?? 'null',
              ),
            );
          }
          request.response.statusCode = HttpStatus.noContent;
        } else {
          final mediaUrl = request.uri.queryParameters['url'] ?? '';
          request.response.headers.contentType = ContentType.html;
          request.response.write(_playerHtml(mediaUrl));
        }
      } catch (_) {
        request.response.statusCode = HttpStatus.badRequest;
      } finally {
        await request.response.close();
      }
    }
  }

  String _playerHtml(String mediaUrl) {
    final safeUrl = const HtmlEscape().convert(mediaUrl);
    return '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;background:#000;overflow:hidden">
<video id="player" src="$safeUrl" controls autoplay
  style="width:100vw;height:100vh;object-fit:contain"></video>
</body></html>''';
  }

  Future<void> dispose() async {
    final server = _server;
    _server = null;
    _onMessage = null;
    if (server != null) await server.close(force: true);
  }
}
