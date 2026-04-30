import 'package:flutter_test/flutter_test.dart';
import 'package:files_tech_core/files_tech_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ── RecentFile ─────────────────────────────────────────────────────────────

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

  group('RecentFile.fromJson defensive', () {
    test('throws on missing path', () {
      expect(() => RecentFile.fromJson({'name': 'x',
          'lastOpened': '2026-01-01T00:00:00Z', 'sizeBytes': 0}),
          throwsFormatException);
    });
    test('throws on negative size', () {
      expect(() => RecentFile.fromJson({'path': '/x', 'name': 'x',
          'lastOpened': '2026-01-01T00:00:00Z', 'sizeBytes': -1}),
          throwsFormatException);
    });
    test('throws on bad type', () {
      expect(() => RecentFile.fromJson({'path': 42, 'name': 'x',
          'lastOpened': '2026-01-01T00:00:00Z', 'sizeBytes': 0}),
          throwsFormatException);
    });
    test('throws on invalid date', () {
      expect(() => RecentFile.fromJson({'path': '/x', 'name': 'x',
          'lastOpened': 'not-a-date', 'sizeBytes': 0}),
          throwsFormatException);
    });
  });

  test('RecentFile.formattedSize delegates to FormatUtils', () {
    expect(
      RecentFile(path: '/x', name: 'x',
        lastOpened: DateTime.fromMillisecondsSinceEpoch(0),
        sizeBytes: 1500).formattedSize,
      '1.5 Ko',
    );
  });

  test('RecentFile.extension', () {
    final f = RecentFile(path: '/x', name: 'Foo.PDF',
        lastOpened: DateTime.fromMillisecondsSinceEpoch(0), sizeBytes: 0);
    expect(f.extension, 'pdf');
  });

  // ── RecentFilesService ─────────────────────────────────────────────────────

  group('RecentFilesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load empty', () async {
      const svc = RecentFilesService();
      expect(await svc.load(), isEmpty);
    });

    test('load skips corrupted entries', () async {
      SharedPreferences.setMockInitialValues({
        'recent_files': [
          'not-json',
          '{"path":42}',  // bad type
          '{"path":"/nonexistent/foo.pdf","name":"foo.pdf",'
              '"lastOpened":"2026-01-01T00:00:00Z","sizeBytes":0}',
          // pas de fichier qui existe → tous filtrés
        ],
      });
      const svc = RecentFilesService();
      expect(await svc.load(), isEmpty);
      // Auto-purge : prefs réécrits sans les entrées corrompues
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_files'), isEmpty);
    });
  });

  // ── FormatUtils.bytes ──────────────────────────────────────────────────────

  group('FormatUtils.bytes', () {
    test('B', () => expect(FormatUtils.bytes(500), '500 B'));
    test('Ko', () => expect(FormatUtils.bytes(1500), '1.5 Ko'));
    test('Mo', () => expect(FormatUtils.bytes(1500000), '1.4 Mo'));
    test('Go', () => expect(FormatUtils.bytes(2147483648), '2.0 Go'));
    test('negative guarded', () => expect(FormatUtils.bytes(-1), '0 B'));
  });

  group('FormatUtils.bytesStorage', () {
    test('MB no decimal',
        () => expect(FormatUtils.bytesStorage(1500000), '1 MB'));
    test('GB',
        () => expect(FormatUtils.bytesStorage(2147483648), '2.0 GB'));
    test('zero', () => expect(FormatUtils.bytesStorage(0), '0 B'));
    test('negative', () => expect(FormatUtils.bytesStorage(-1), '0 B'));
  });

  // ── PathSafe ───────────────────────────────────────────────────────────────

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

  group('PathSafe.sanitizeForFs', () {
    test('whitespace to underscore', () =>
        expect(PathSafe.sanitizeForFs('hello world'), 'hello_world'));
    test('strip leading dots', () =>
        expect(PathSafe.sanitizeForFs('.hidden'), 'hidden'));
    test('strip trailing dots', () =>
        expect(PathSafe.sanitizeForFs('foo...'), 'foo'));
    test('collapse underscores', () =>
        expect(PathSafe.sanitizeForFs('a___b'), 'a_b'));
  });

  // ── UpdateService ──────────────────────────────────────────────────────────

  group('UpdateService.isNewer', () {
    test('strictly newer',
        () => expect(UpdateService.isNewer('1.8.0', '1.7.2'), isTrue));
    test('major bump',
        () => expect(UpdateService.isNewer('2.0.0', '1.99.99'), isTrue));
    test('equal',
        () => expect(UpdateService.isNewer('1.8.0', '1.8.0'), isFalse));
    test('older',
        () => expect(UpdateService.isNewer('1.7.0', '1.8.0'), isFalse));
    test('patch',
        () => expect(UpdateService.isNewer('1.8.1', '1.8.0'), isTrue));
  });
}
