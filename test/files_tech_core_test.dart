import 'dart:typed_data';

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
      expect(
        () => RecentFile.fromJson({
          'name': 'x',
          'lastOpened': '2026-01-01T00:00:00Z',
          'sizeBytes': 0,
        }),
        throwsFormatException,
      );
    });
    test('throws on negative size', () {
      expect(
        () => RecentFile.fromJson({
          'path': '/x',
          'name': 'x',
          'lastOpened': '2026-01-01T00:00:00Z',
          'sizeBytes': -1,
        }),
        throwsFormatException,
      );
    });
    test('throws on bad type', () {
      expect(
        () => RecentFile.fromJson({
          'path': 42,
          'name': 'x',
          'lastOpened': '2026-01-01T00:00:00Z',
          'sizeBytes': 0,
        }),
        throwsFormatException,
      );
    });
    test('throws on invalid date', () {
      expect(
        () => RecentFile.fromJson({
          'path': '/x',
          'name': 'x',
          'lastOpened': 'not-a-date',
          'sizeBytes': 0,
        }),
        throwsFormatException,
      );
    });
  });

  test('RecentFile.formattedSize delegates to FormatUtils', () {
    expect(
      RecentFile(
        path: '/x',
        name: 'x',
        lastOpened: DateTime.fromMillisecondsSinceEpoch(0),
        sizeBytes: 1500,
      ).formattedSize,
      '1.5 Ko',
    );
  });

  test('RecentFile.extension', () {
    final f = RecentFile(
      path: '/x',
      name: 'Foo.PDF',
      lastOpened: DateTime.fromMillisecondsSinceEpoch(0),
      sizeBytes: 0,
    );
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
          '{"path":42}', // bad type
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
    test(
      'MB no decimal',
      () => expect(FormatUtils.bytesStorage(1500000), '1 MB'),
    );
    test('GB', () => expect(FormatUtils.bytesStorage(2147483648), '2.0 GB'));
    test('zero', () => expect(FormatUtils.bytesStorage(0), '0 B'));
    test('negative', () => expect(FormatUtils.bytesStorage(-1), '0 B'));
  });

  // ── PathSafe ───────────────────────────────────────────────────────────────

  group('PathSafe.basename', () {
    test('valid', () => expect(PathSafe.basename('/tmp/foo.pdf'), 'foo.pdf'));
    test(
      'windows',
      () => expect(PathSafe.basename(r'C:\Users\bar.pdf'), 'bar.pdf'),
    );
    test(
      'throws on ..',
      () => expect(() => PathSafe.basename('..'), throwsArgumentError),
    );
  });

  group('PathSafe.sanitizeFileName', () {
    test(
      'strip slashes',
      () => expect(PathSafe.sanitizeFileName('a/b\\c'), 'a_b_c'),
    );
    test(
      'strip dots',
      () => expect(PathSafe.sanitizeFileName('foo..bar'), 'foo_bar'),
    );
    test(
      'truncate',
      () => expect(PathSafe.sanitizeFileName('x' * 100, maxLen: 10).length, 10),
    );
    test(
      'empty fallback',
      () => expect(PathSafe.sanitizeFileName('   '), 'fichier'),
    );
    test(
      'dot fallback',
      () => expect(PathSafe.sanitizeFileName('.'), 'fichier'),
    );
  });

  group('PathSafe.sanitizeForFs', () {
    test(
      'whitespace to underscore',
      () => expect(PathSafe.sanitizeForFs('hello world'), 'hello_world'),
    );
    test(
      'strip leading dots',
      () => expect(PathSafe.sanitizeForFs('.hidden'), 'hidden'),
    );
    test(
      'strip trailing dots',
      () => expect(PathSafe.sanitizeForFs('foo...'), 'foo'),
    );
    test(
      'collapse underscores',
      () => expect(PathSafe.sanitizeForFs('a___b'), 'a_b'),
    );
  });

  // ── SecretBytes ────────────────────────────────────────────────────────────

  group('SecretBytes.randomBytes', () {
    test('n=0 returns empty', () {
      expect(SecretBytes.randomBytes(0), isEmpty);
    });
    test('n=1 returns 1 byte', () {
      expect(SecretBytes.randomBytes(1).length, 1);
    });
    test('n=16 returns 16 bytes', () {
      expect(SecretBytes.randomBytes(16).length, 16);
    });
    test('n=32 returns 32 bytes', () {
      expect(SecretBytes.randomBytes(32).length, 32);
    });
    test('two calls differ (CSPRNG)', () {
      final a = SecretBytes.randomBytes(32);
      final b = SecretBytes.randomBytes(32);
      expect(a, isNot(equals(b)));
    });
    test('negative n throws', () {
      expect(() => SecretBytes.randomBytes(-1), throwsArgumentError);
    });
  });

  group('SecretBytes.wipe', () {
    test('zeroes the buffer', () {
      final buf = Uint8List.fromList([1, 2, 3, 4, 5]);
      SecretBytes.wipe(buf);
      expect(buf, [0, 0, 0, 0, 0]);
    });
    test('empty buffer is a no-op', () {
      final buf = Uint8List(0);
      SecretBytes.wipe(buf);
      expect(buf, isEmpty);
    });
  });

  group('SecretBytes.constantTimeEq', () {
    test('equal returns true', () {
      expect(SecretBytes.constantTimeEq([1, 2, 3], [1, 2, 3]), isTrue);
    });
    test('different content returns false', () {
      expect(SecretBytes.constantTimeEq([1, 2, 3], [1, 2, 4]), isFalse);
    });
    test('different lengths return false', () {
      expect(SecretBytes.constantTimeEq([1, 2, 3], [1, 2]), isFalse);
    });
    test('both empty returns true', () {
      expect(SecretBytes.constantTimeEq(<int>[], <int>[]), isTrue);
    });
    test('Uint8List interop', () {
      final a = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      final b = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      expect(SecretBytes.constantTimeEq(a, b), isTrue);
    });
  });

  group('SecretBytes.toHex', () {
    test('simple bytes', () {
      expect(SecretBytes.toHex(Uint8List.fromList([0xAB, 0xCD])), 'abcd');
    });
    test('zero padding', () {
      expect(
        SecretBytes.toHex(Uint8List.fromList([0x00, 0x01, 0x0F])),
        '00010f',
      );
    });
    test('empty buffer returns empty string', () {
      expect(SecretBytes.toHex(Uint8List(0)), '');
    });
    test('all 0xFF', () {
      expect(SecretBytes.toHex(Uint8List.fromList([0xFF, 0xFF])), 'ffff');
    });
    test('round-trip toHex/fromHex', () {
      final orig = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x42]);
      expect(SecretBytes.fromHex(SecretBytes.toHex(orig)), orig);
    });
  });

  group('SecretBytes.fromHex', () {
    test('simple decode', () {
      expect(SecretBytes.fromHex('abcd'), Uint8List.fromList([0xAB, 0xCD]));
    });
    test('uppercase tolerated', () {
      expect(
        SecretBytes.fromHex('DEADBEEF'),
        Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
      );
    });
    test('empty string returns empty', () {
      expect(SecretBytes.fromHex(''), isEmpty);
    });
    test('odd length throws', () {
      expect(() => SecretBytes.fromHex('abc'), throwsFormatException);
    });
    test('invalid hex chars throws', () {
      expect(() => SecretBytes.fromHex('zzzz'), throwsFormatException);
    });
  });

  group('SecretBytes.constantTimeEqHex', () {
    test('equal returns true', () {
      expect(SecretBytes.constantTimeEqHex('abcd', 'abcd'), isTrue);
    });
    test('different content returns false', () {
      expect(SecretBytes.constantTimeEqHex('abcd', 'abce'), isFalse);
    });
    test('different lengths throws', () {
      expect(
        () => SecretBytes.constantTimeEqHex('abcd', 'abcdef'),
        throwsArgumentError,
      );
    });
    test('both empty returns true', () {
      expect(SecretBytes.constantTimeEqHex('', ''), isTrue);
    });
    test('case sensitive (does not normalize)', () {
      expect(SecretBytes.constantTimeEqHex('abcd', 'ABCD'), isFalse);
    });
  });

  // ── UpdateService ──────────────────────────────────────────────────────────

  group('UpdateService.isNewer', () {
    test(
      'strictly newer',
      () => expect(UpdateService.isNewer('1.8.0', '1.7.2'), isTrue),
    );
    test(
      'major bump',
      () => expect(UpdateService.isNewer('2.0.0', '1.99.99'), isTrue),
    );
    test(
      'equal',
      () => expect(UpdateService.isNewer('1.8.0', '1.8.0'), isFalse),
    );
    test(
      'older',
      () => expect(UpdateService.isNewer('1.7.0', '1.8.0'), isFalse),
    );
    test(
      'patch',
      () => expect(UpdateService.isNewer('1.8.1', '1.8.0'), isTrue),
    );
  });
}
