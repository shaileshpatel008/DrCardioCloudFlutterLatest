/// The cardiologist's advice is stored as HTML (the web panel used a rich
/// text editor and the report PDF is rendered from that HTML). The app edits
/// it as plain text: paragraphs per line, and lines starting with "•" or "-"
/// become a bullet list. These two helpers convert both ways.
class HtmlText {
  HtmlText._();

  static String toPlain(String? html) {
    if (html == null || html.trim().isEmpty) return '';
    var s = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    s = _decode(s);
    return s.split('\n').map((l) => l.trimRight()).where((l) => l.trim().isNotEmpty).join('\n').trim();
  }

  static String toHtml(String plain) {
    final lines = plain.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final out = StringBuffer();
    var inList = false;
    for (final line in lines) {
      final bullet = line.startsWith('• ') || line.startsWith('- ') || line.startsWith('* ');
      if (bullet) {
        if (!inList) {
          out.write('<ul>');
          inList = true;
        }
        out.write('<li>${_escape(line.substring(2).trim())}</li>');
      } else {
        if (inList) {
          out.write('</ul>');
          inList = false;
        }
        out.write('<p>${_escape(line)}</p>');
      }
    }
    if (inList) out.write('</ul>');
    return out.toString();
  }

  static String _escape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  static String _decode(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#039;', "'")
      .replaceAll('&amp;', '&');
}
