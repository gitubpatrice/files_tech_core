import 'package:flutter_test/flutter_test.dart';
import 'package:files_tech_core/files_tech_core.dart';

void main() {
  test('RecentFile JSON round-trip', () {
    final orig = RecentFile(
      path: '/tmp/foo.pdf',
      name: 'foo.pdf',
      lastOpened: DateTime.parse('2026-04-30T12:00:00Z'),
      sizeBytes: 1234,
      isFavorite: true,
    );
    final encoded = orig.toJsonString();
    final decoded = RecentFile.fromJsonString(encoded);
    expect(decoded.path, orig.path);
    expect(decoded.name, orig.name);
    expect(decoded.lastOpened, orig.lastOpened);
    expect(decoded.sizeBytes, orig.sizeBytes);
    expect(decoded.isFavorite, orig.isFavorite);
  });

  group('FormatUtils.bytes', () {
    test('B', () => expect(FormatUtils.bytes(500), '500 B'));
    test('Ko', () => expect(FormatUtils.bytes(1500), '1.5 Ko'));
    test('Mo', () => expect(FormatUtils.bytes(1500000), '1.4 Mo'));
    test('Go', () => expect(FormatUtils.bytes(2147483648), '2.0 Go'));
  });

  group('PathSafe.basename', () {
    test('valid', () => expect(PathSafe.basename('/tmp/foo.pdf'), 'foo.pdf'));
    test('windows', () =>
        expect(PathSafe.basename(r'C:\Users\bar.pdf'), 'bar.pdf'));
    test('throws on ..', () =>
        expect(() => PathSafe.basename('..'), throwsArgumentError));
  });

  group('PathSafe.sanitizeFileName', () {
    test('strip slashes', () =>
        expect(PathSafe.sanitizeFileName('a/b\\c'), 'a_b_c'));
    test('strip dots', () =>
        expect(PathSafe.sanitizeFileName('foo..bar'), 'foo_bar'));
    test('truncate', () =>
        expect(PathSafe.sanitizeFileName('x' * 100, maxLen: 10).length, 10));
    test('empty fallback', () =>
        expect(PathSafe.sanitizeFileName('   '), 'fichier'));
    test('dot fallback', () =>
        expect(PathSafe.sanitizeFileName('.'), 'fichier'));
  });

  test('RecentFile.formattedSize', () {
    final r1 = RecentFile(
      path: '/x', name: 'x',
      lastOpened: DateTime.fromMillisecondsSinceEpoch(0),
      sizeBytes: 500,
    );
    final r2 = RecentFile(
      path: '/x', name: 'x',
      lastOpened: DateTime.fromMillisecondsSinceEpoch(0),
      sizeBytes: 1500,
    );
    final r3 = RecentFile(
      path: '/x', name: 'x',
      lastOpened: DateTime.fromMillisecondsSinceEpoch(0),
      sizeBytes: 1500000,
    );
    expect(r1.formattedSize, '500 B');
    expect(r2.formattedSize, '1.5 Ko');
    expect(r3.formattedSize, '1.4 Mo');
  });
}
