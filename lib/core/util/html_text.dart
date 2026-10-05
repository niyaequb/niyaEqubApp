/// Turns the rich text an admin typed into the CMS into plain text that keeps
/// its shape.
///
/// Terms come back from the server as HTML. Everything that reads them —
/// TermsScreen's structure parser above all — works on lines, so the job here
/// is not to strip tags but to turn each block-level tag into the line break
/// it stood for. A naive `replaceAll(RegExp(r'<[^>]*>'), '')` runs the whole
/// document into one paragraph, which is how a numbered contract ends up as a
/// wall of text with the clause numbers buried mid-line.
///
/// List items keep a bullet, because the parser recognises one and the reader
/// renders it; losing `<li>` is losing the fact that something was a list at
/// all.
library;

/// `<script>`/`<style>` and everything between them. Their contents are not
/// prose and must go before tags are stripped, or the CSS ends up on the page.
final _scriptOrStyle = RegExp(
  r'<(script|style)\b[^>]*>[\s\S]*?</\1\s*>',
  caseSensitive: false,
);

final _lineBreak = RegExp(r'<br\s*/?>', caseSensitive: false);

/// Opening list item: becomes the bullet the reader will draw.
final _listItemOpen = RegExp(r'<li\b[^>]*>', caseSensitive: false);

/// Cells run together on one line with a separator rather than stacking.
final _cellEnd = RegExp(r'</t[dh]\s*>', caseSensitive: false);

/// Anything that ends a line but not a paragraph.
final _lineEnd = RegExp(r'</(li|tr|thead|tbody)\s*>', caseSensitive: false);

/// Anything that ends a paragraph.
final _blockEnd = RegExp(
  r'</(p|div|h[1-6]|ul|ol|table|blockquote|section|article|header|footer)\s*>',
  caseSensitive: false,
);

final _anyTag = RegExp(r'<[^>]*>');
final _decimalEntity = RegExp(r'&#(\d{1,7});');
final _hexEntity = RegExp(r'&#x([0-9a-fA-F]{1,6});', caseSensitive: false);
final _tooManyBreaks = RegExp(r'\n{3,}');

/// Named entities an editor actually produces. Anything rarer is left alone
/// rather than guessed at — a stray `&xyz;` on screen is better than dropping
/// a character that mattered.
const _entities = <String, String>{
  '&quot;': '"',
  '&apos;': "'",
  '&#39;': "'",
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&nbsp;': ' ',
  '&ensp;': ' ',
  '&emsp;': ' ',
  '&thinsp;': ' ',
  '&ndash;': '–',
  '&mdash;': '—',
  '&lsquo;': '‘',
  '&rsquo;': '’',
  '&ldquo;': '“',
  '&rdquo;': '”',
  '&hellip;': '…',
  '&bull;': '•',
  '&middot;': '·',
  '&laquo;': '«',
  '&raquo;': '»',
  '&deg;': '°',
  '&euro;': '€',
  '&pound;': '£',
  '&copy;': '©',
  '&reg;': '®',
  '&trade;': '™',
};

/// Plain text, laid out in lines, from [html].
///
/// Safe to call on text that was never HTML: with no tags and no entities it
/// only trims and tidies the blank lines.
String htmlToPlainText(String? html) {
  final source = html ?? '';
  if (source.trim().isEmpty) return '';

  var text = source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(_scriptOrStyle, '')
      .replaceAll(_lineBreak, '\n')
      // Before </li> is turned into a line end, so the bullet lands at the
      // start of the item's own line.
      .replaceAll(_listItemOpen, '\n• ')
      .replaceAll(_cellEnd, '  ')
      .replaceAll(_lineEnd, '\n')
      .replaceAll(_blockEnd, '\n\n')
      .replaceAll(_anyTag, '');

  // Entities last: decoding first would let a written-out "&lt;p&gt;" be
  // stripped as if it were a real tag.
  _entities.forEach((entity, char) => text = text.replaceAll(entity, char));

  text = text.replaceAllMapped(_decimalEntity, (m) {
    final code = int.tryParse(m.group(1)!);
    return _isSafeCodePoint(code) ? String.fromCharCode(code!) : m.group(0)!;
  });

  text = text.replaceAllMapped(_hexEntity, (m) {
    final code = int.tryParse(m.group(1)!, radix: 16);
    return _isSafeCodePoint(code) ? String.fromCharCode(code!) : m.group(0)!;
  });

  return text
      .split('\n')
      .map((line) => line.trim())
      // A line that is only a leftover bullet carries nothing.
      .map((line) => line == '•' ? '' : line)
      .join('\n')
      .replaceAll(_tooManyBreaks, '\n\n')
      .trim();
}

/// Rejects surrogates and anything past the Unicode range, which
/// `String.fromCharCode` would otherwise turn into a replacement character or
/// throw on.
bool _isSafeCodePoint(int? code) =>
    code != null &&
    code > 0 &&
    code <= 0x10FFFF &&
    !(code >= 0xD800 && code <= 0xDFFF);
