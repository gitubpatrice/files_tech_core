import 'package:flutter_test/flutter_test.dart';
import 'package:files_tech_core/files_tech_core.dart';

void main() {
  group('PathUtils.fileName', () {
    test('unix path', () {
      expect(PathUtils.fileName('/a/b/c.pdf'), 'c.pdf');
    });
    test('windows path', () {
      expect(PathUtils.fileName(r'C:\Users\Pat\foo.txt'), 'foo.txt');
    });
    test('mixed separators', () {
      expect(PathUtils.fileName('/a/b\\c/d.md'), 'd.md');
    });
    test('no separator returns input', () {
      expect(PathUtils.fileName('foo.pdf'), 'foo.pdf');
    });
    test('empty returns empty', () {
      expect(PathUtils.fileName(''), '');
    });
    test('trailing separator returns empty name', () {
      expect(PathUtils.fileName('/a/b/'), '');
    });
  });

  group('PathUtils.fileExt', () {
    test('lowercase', () {
      expect(PathUtils.fileExt('doc.PDF'), 'pdf');
    });
    test('unix path', () {
      expect(PathUtils.fileExt('/a/b/c.txt'), 'txt');
    });
    test('no extension', () {
      expect(PathUtils.fileExt('/a/b/README'), '');
    });
    test('hidden unix file (no ext)', () {
      expect(PathUtils.fileExt('.bashrc'), '');
    });
    test('trailing dot returns empty', () {
      expect(PathUtils.fileExt('foo.'), '');
    });
    test('double extension keeps last', () {
      expect(PathUtils.fileExt('archive.tar.gz'), 'gz');
    });
    test('empty string', () {
      expect(PathUtils.fileExt(''), '');
    });
  });

  group('PathUtils.fileBaseName', () {
    test('unix path with ext', () {
      expect(PathUtils.fileBaseName('/a/b/c.pdf'), 'c');
    });
    test('windows path with ext', () {
      expect(PathUtils.fileBaseName(r'C:\Users\foo.txt'), 'foo');
    });
    test('no extension keeps name', () {
      expect(PathUtils.fileBaseName('/a/b/README'), 'README');
    });
    test('hidden unix file kept whole', () {
      expect(PathUtils.fileBaseName('.bashrc'), '.bashrc');
    });
    test('double extension strips only last', () {
      expect(PathUtils.fileBaseName('archive.tar.gz'), 'archive.tar');
    });
    test('empty string', () {
      expect(PathUtils.fileBaseName(''), '');
    });
  });
}
