import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io' show Platform;

class HtmlContentViewer extends StatelessWidget {
  final String html;
  const HtmlContentViewer({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux) {
      return InAppWebView(
        initialData: InAppWebViewInitialData(
          data: '''
            <!DOCTYPE html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <meta charset="UTF-8">
              <style>
                body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
                  line-height: 1.6;
                  color: #333;
                  margin: 0;
                  padding: 0;
                  overflow-x: hidden;
                  word-wrap: break-word;
                }
                img { max-width: 100%; height: auto; border-radius: 8px; margin: 10px 0; }
                h1, h2, h3 { color: #1976D2; margin: 20px 0 10px 0; }
                p { margin: 15px 0; }
                video { max-width: 100%; border-radius: 8px; margin: 10px 0; }
                hr { border: 0; height: 1px; background: #ddd; margin: 20px 0; }
              </style>
            </head>
            <body>$html</body>
            </html>
          ''',
        ),
        initialSettings: InAppWebViewSettings(
          verticalScrollBarEnabled: false,
          horizontalScrollBarEnabled: false,
          transparentBackground: true,
          useWideViewPort: true,
          loadWithOverviewMode: true,
        ),
      );
    } else {
      return _buildPlainText();
    }
  }

  Widget _buildPlainText() {
    String text = html
        .replaceAll(RegExp(r'<h1[^>]*>([^<]*)</h1>'), '\n\n\$1\n\n')
        .replaceAll(RegExp(r'<h2[^>]*>([^<]*)</h2>'), '\n\n\$1\n\n')
        .replaceAll(RegExp(r'<p[^>]*>([^<]*)</p>'), '\n\$1\n')
        .replaceAll(RegExp(r'<br[^>]*>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');

    return SelectableText(
      text,
      style: const TextStyle(fontSize: 16, height: 1.6),
    );
  }
}
