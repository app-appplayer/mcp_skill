import 'package:test/test.dart';
import 'package:mcp_skill/src/dependency/version_constraint.dart';

void main() {
  group('SemanticVersion', () {
    group('parsing', () {
      test('parses major.minor.patch', () {
        final v = SemanticVersion.parse('1.2.3');
        expect(v.major, 1);
        expect(v.minor, 2);
        expect(v.patch, 3);
        expect(v.preRelease, isEmpty);
        expect(v.build, isNull);
      });

      test('parses version with pre-release identifiers', () {
        final v = SemanticVersion.parse('1.0.0-alpha.1');
        expect(v.major, 1);
        expect(v.minor, 0);
        expect(v.patch, 0);
        expect(v.preRelease, ['alpha', '1']);
        expect(v.isPrerelease, true);
      });

      test('parses version with build metadata', () {
        final v = SemanticVersion.parse('1.0.0+build.42');
        expect(v.major, 1);
        expect(v.build, 'build.42');
      });

      test('parses version with pre-release and build', () {
        final v = SemanticVersion.parse('2.1.0-beta.3+sha.abc');
        expect(v.major, 2);
        expect(v.minor, 1);
        expect(v.patch, 0);
        expect(v.preRelease, ['beta', '3']);
        expect(v.build, 'sha.abc');
      });

      test('throws FormatException for invalid version', () {
        expect(
          () => SemanticVersion.parse('invalid'),
          throwsFormatException,
        );
      });

      test('throws FormatException for partial version', () {
        expect(
          () => SemanticVersion.parse('1.2'),
          throwsFormatException,
        );
      });

      test('trims whitespace before parsing', () {
        final v = SemanticVersion.parse('  1.2.3  ');
        expect(v.major, 1);
        expect(v.minor, 2);
        expect(v.patch, 3);
      });
    });

    group('zero constant', () {
      test('is 0.0.0', () {
        expect(SemanticVersion.zero.major, 0);
        expect(SemanticVersion.zero.minor, 0);
        expect(SemanticVersion.zero.patch, 0);
      });
    });

    group('isPrerelease', () {
      test('returns false for stable version', () {
        final v = SemanticVersion.parse('1.0.0');
        expect(v.isPrerelease, false);
      });

      test('returns true for pre-release version', () {
        final v = SemanticVersion.parse('1.0.0-alpha');
        expect(v.isPrerelease, true);
      });
    });

    group('comparison operators', () {
      test('less than compares correctly', () {
        final v1 = SemanticVersion.parse('1.0.0');
        final v2 = SemanticVersion.parse('2.0.0');
        expect(v1 < v2, true);
        expect(v2 < v1, false);
      });

      test('greater than compares correctly', () {
        final v1 = SemanticVersion.parse('1.0.0');
        final v2 = SemanticVersion.parse('0.9.0');
        expect(v1 > v2, true);
      });

      test('equality', () {
        final v1 = SemanticVersion.parse('1.2.3');
        final v2 = SemanticVersion.parse('1.2.3');
        expect(v1 == v2, true);
      });

      test('less than or equal', () {
        final v1 = SemanticVersion.parse('1.0.0');
        final v2 = SemanticVersion.parse('1.0.0');
        expect(v1 <= v2, true);
        expect(SemanticVersion.parse('0.9.0') <= v2, true);
      });

      test('greater than or equal', () {
        final v1 = SemanticVersion.parse('2.0.0');
        final v2 = SemanticVersion.parse('2.0.0');
        expect(v1 >= v2, true);
        expect(SemanticVersion.parse('2.0.1') >= v2, true);
      });

      test('minor version comparison', () {
        final v1 = SemanticVersion.parse('1.1.0');
        final v2 = SemanticVersion.parse('1.2.0');
        expect(v1 < v2, true);
      });

      test('patch version comparison', () {
        final v1 = SemanticVersion.parse('1.0.1');
        final v2 = SemanticVersion.parse('1.0.2');
        expect(v1 < v2, true);
      });

      test('pre-release has lower precedence than release', () {
        final alpha = SemanticVersion.parse('1.0.0-alpha');
        final release = SemanticVersion.parse('1.0.0');
        expect(alpha < release, true);
        expect(release > alpha, true);
      });

      test('pre-release identifiers are compared', () {
        final alpha = SemanticVersion.parse('1.0.0-alpha');
        final beta = SemanticVersion.parse('1.0.0-beta');
        expect(alpha < beta, true);
      });

      test('numeric pre-release identifiers sort numerically', () {
        final v1 = SemanticVersion.parse('1.0.0-alpha.1');
        final v2 = SemanticVersion.parse('1.0.0-alpha.2');
        expect(v1 < v2, true);
      });

      test('numeric identifiers sort before string identifiers', () {
        final numeric = SemanticVersion.parse('1.0.0-1');
        final alpha = SemanticVersion.parse('1.0.0-alpha');
        expect(numeric < alpha, true);
      });

      test('fewer pre-release identifiers have lower precedence', () {
        final short = SemanticVersion.parse('1.0.0-alpha');
        final long = SemanticVersion.parse('1.0.0-alpha.1');
        expect(short < long, true);
      });
    });

    group('increment methods', () {
      test('nextMajor increments major and resets minor and patch', () {
        final v = SemanticVersion.parse('1.2.3').nextMajor();
        expect(v.toString(), '2.0.0');
      });

      test('nextMinor increments minor and resets patch', () {
        final v = SemanticVersion.parse('1.2.3').nextMinor();
        expect(v.toString(), '1.3.0');
      });

      test('nextPatch increments patch only', () {
        final v = SemanticVersion.parse('1.2.3').nextPatch();
        expect(v.toString(), '1.2.4');
      });

      test('nextBreaking for major > 0 returns next major', () {
        final v = SemanticVersion.parse('1.2.3').nextBreaking();
        expect(v.toString(), '2.0.0');
      });

      test('nextBreaking for 0.x.y returns next minor', () {
        final v = SemanticVersion.parse('0.2.3').nextBreaking();
        expect(v.toString(), '0.3.0');
      });

      test('nextBreaking for 0.0.x returns next patch', () {
        final v = SemanticVersion.parse('0.0.3').nextBreaking();
        expect(v.toString(), '0.0.4');
      });
    });

    group('toString', () {
      test('formats basic version', () {
        final v = SemanticVersion(major: 1, minor: 2, patch: 3);
        expect(v.toString(), '1.2.3');
      });

      test('formats with pre-release', () {
        const v = SemanticVersion(
          major: 1,
          minor: 0,
          patch: 0,
          preRelease: ['alpha', '1'],
        );
        expect(v.toString(), '1.0.0-alpha.1');
      });

      test('formats with build', () {
        const v = SemanticVersion(major: 1, minor: 0, patch: 0, build: 'abc');
        expect(v.toString(), '1.0.0+abc');
      });

      test('formats with both pre-release and build', () {
        const v = SemanticVersion(
          major: 1,
          minor: 0,
          patch: 0,
          preRelease: ['rc', '1'],
          build: 'build.5',
        );
        expect(v.toString(), '1.0.0-rc.1+build.5');
      });
    });

    group('equality and hashCode', () {
      test('equal versions have same hashCode', () {
        final v1 = SemanticVersion.parse('1.2.3');
        final v2 = SemanticVersion.parse('1.2.3');
        expect(v1.hashCode, v2.hashCode);
      });

      test('different versions are not equal', () {
        final v1 = SemanticVersion.parse('1.2.3');
        final v2 = SemanticVersion.parse('1.2.4');
        expect(v1 == v2, false);
      });

      test('pre-release affects equality', () {
        final v1 = SemanticVersion.parse('1.0.0-alpha');
        final v2 = SemanticVersion.parse('1.0.0');
        expect(v1 == v2, false);
      });
    });

    group('JSON serialization', () {
      test('toJson produces correct map', () {
        const v = SemanticVersion(
          major: 1,
          minor: 2,
          patch: 3,
          preRelease: ['beta'],
          build: 'sha1',
        );
        final json = v.toJson();
        expect(json['major'], 1);
        expect(json['minor'], 2);
        expect(json['patch'], 3);
        expect(json['preRelease'], ['beta']);
        expect(json['build'], 'sha1');
      });

      test('fromJson round-trips correctly', () {
        const v = SemanticVersion(
          major: 2,
          minor: 0,
          patch: 1,
          preRelease: ['rc', '2'],
        );
        final restored = SemanticVersion.fromJson(v.toJson());
        expect(restored, v);
      });
    });
  });

  group('VersionConstraint.parse', () {
    test('parses exact version', () {
      final c = VersionConstraint.parse('1.0.0');
      expect(c.allows(SemanticVersion.parse('1.0.0')), true);
      expect(c.allows(SemanticVersion.parse('1.0.1')), false);
    });

    test('parses "*" as any', () {
      final c = VersionConstraint.parse('*');
      expect(c.isAny, true);
      expect(c.allows(SemanticVersion.parse('99.99.99')), true);
    });

    test('parses "any" as any', () {
      final c = VersionConstraint.parse('any');
      expect(c.isAny, true);
    });

    test('parses empty string as any', () {
      final c = VersionConstraint.parse('');
      expect(c.isAny, true);
    });

    test('parses range with >= and <', () {
      final c = VersionConstraint.parse('>=1.0.0 <2.0.0');
      expect(c.allows(SemanticVersion.parse('1.0.0')), true);
      expect(c.allows(SemanticVersion.parse('1.5.0')), true);
      expect(c.allows(SemanticVersion.parse('2.0.0')), false);
      expect(c.allows(SemanticVersion.parse('0.9.0')), false);
    });

    test('parses range with > and <=', () {
      final c = VersionConstraint.parse('>1.0.0 <=2.0.0');
      expect(c.allows(SemanticVersion.parse('1.0.0')), false);
      expect(c.allows(SemanticVersion.parse('1.0.1')), true);
      expect(c.allows(SemanticVersion.parse('2.0.0')), true);
      expect(c.allows(SemanticVersion.parse('2.0.1')), false);
    });

    test('parses caret constraint ^1.0.0', () {
      final c = VersionConstraint.parse('^1.0.0');
      expect(c, isA<CaretConstraint>());
      expect(c.allows(SemanticVersion.parse('1.0.0')), true);
      expect(c.allows(SemanticVersion.parse('1.9.9')), true);
      expect(c.allows(SemanticVersion.parse('2.0.0')), false);
    });

    test('parses tilde constraint ~1.2.3', () {
      final c = VersionConstraint.parse('~1.2.3');
      expect(c, isA<TildeConstraint>());
      expect(c.allows(SemanticVersion.parse('1.2.3')), true);
      expect(c.allows(SemanticVersion.parse('1.2.9')), true);
      expect(c.allows(SemanticVersion.parse('1.3.0')), false);
    });

    test('parses union with ||', () {
      final c = VersionConstraint.parse('1.0.0 || 2.0.0');
      expect(c.allows(SemanticVersion.parse('1.0.0')), true);
      expect(c.allows(SemanticVersion.parse('2.0.0')), true);
      expect(c.allows(SemanticVersion.parse('1.5.0')), false);
    });
  });

  group('VersionRange', () {
    test('any range allows everything', () {
      const range = VersionRange();
      expect(range.isAny, true);
      expect(range.isEmpty, false);
      expect(range.allows(SemanticVersion.parse('100.0.0')), true);
    });

    test('exact version range', () {
      final range = VersionRange.exact(SemanticVersion.parse('1.0.0'));
      expect(range.allows(SemanticVersion.parse('1.0.0')), true);
      expect(range.allows(SemanticVersion.parse('1.0.1')), false);
    });

    test('isEmpty for inverted range', () {
      final range = VersionRange(
        min: SemanticVersion.parse('2.0.0'),
        max: SemanticVersion.parse('1.0.0'),
        includeMin: true,
        includeMax: true,
      );
      expect(range.isEmpty, true);
    });

    test('isEmpty for exclusive equal range', () {
      final range = VersionRange(
        min: SemanticVersion.parse('1.0.0'),
        max: SemanticVersion.parse('1.0.0'),
        includeMin: true,
        includeMax: false,
      );
      expect(range.isEmpty, true);
    });

    test('allows respects includeMin boundary', () {
      final range = VersionRange(
        min: SemanticVersion.parse('1.0.0'),
        includeMin: false,
      );
      expect(range.allows(SemanticVersion.parse('1.0.0')), false);
      expect(range.allows(SemanticVersion.parse('1.0.1')), true);
    });

    test('allows respects includeMax boundary', () {
      final range = VersionRange(
        max: SemanticVersion.parse('2.0.0'),
        includeMax: true,
      );
      expect(range.allows(SemanticVersion.parse('2.0.0')), true);
    });

    group('intersect', () {
      test('intersects two overlapping ranges', () {
        final r1 = VersionRange(
          min: SemanticVersion.parse('1.0.0'),
          max: SemanticVersion.parse('3.0.0'),
        );
        final r2 = VersionRange(
          min: SemanticVersion.parse('2.0.0'),
          max: SemanticVersion.parse('4.0.0'),
        );
        final result = r1.intersect(r2);
        expect(result, isA<VersionRange>());
        expect(result.allows(SemanticVersion.parse('2.0.0')), true);
        expect(result.allows(SemanticVersion.parse('2.5.0')), true);
        expect(result.allows(SemanticVersion.parse('1.5.0')), false);
        expect(result.allows(SemanticVersion.parse('3.5.0')), false);
      });

      test('intersect with empty returns empty', () {
        const range = VersionRange();
        final result = range.intersect(VersionConstraint.empty);
        expect(result, isA<EmptyConstraint>());
      });

      test('intersect of non-overlapping ranges returns empty', () {
        final r1 = VersionRange(
          min: SemanticVersion.parse('1.0.0'),
          max: SemanticVersion.parse('2.0.0'),
          includeMax: false,
        );
        final r2 = VersionRange(
          min: SemanticVersion.parse('3.0.0'),
          max: SemanticVersion.parse('4.0.0'),
        );
        final result = r1.intersect(r2);
        expect(result.isEmpty, true);
      });
    });

    group('union', () {
      test('union of adjacent ranges merges them', () {
        final r1 = VersionRange(
          min: SemanticVersion.parse('1.0.0'),
          max: SemanticVersion.parse('2.0.0'),
          includeMax: true,
        );
        final r2 = VersionRange(
          min: SemanticVersion.parse('2.0.0'),
          max: SemanticVersion.parse('3.0.0'),
        );
        final result = r1.union(r2);
        expect(result, isA<VersionRange>());
        expect(result.allows(SemanticVersion.parse('1.5.0')), true);
        expect(result.allows(SemanticVersion.parse('2.5.0')), true);
      });

      test('union of disjoint ranges returns VersionUnion', () {
        final r1 = VersionRange(
          min: SemanticVersion.parse('1.0.0'),
          max: SemanticVersion.parse('1.5.0'),
          includeMax: false,
        );
        final r2 = VersionRange(
          min: SemanticVersion.parse('3.0.0'),
          max: SemanticVersion.parse('4.0.0'),
        );
        final result = r1.union(r2);
        expect(result, isA<VersionUnion>());
      });

      test('union with empty returns self', () {
        const range = VersionRange();
        final result = range.union(VersionConstraint.empty);
        expect(result.isAny, true);
      });
    });

    group('toString', () {
      test('any range displays as "any"', () {
        const range = VersionRange();
        expect(range.toString(), 'any');
      });

      test('exact range displays version', () {
        final range = VersionRange.exact(SemanticVersion.parse('1.2.3'));
        expect(range.toString(), '1.2.3');
      });

      test('range with min and max displays operators', () {
        final range = VersionRange(
          min: SemanticVersion.parse('1.0.0'),
          max: SemanticVersion.parse('2.0.0'),
          includeMin: true,
          includeMax: false,
        );
        expect(range.toString(), '>=1.0.0 <2.0.0');
      });
    });
  });

  group('CaretConstraint', () {
    test('^1.2.3 allows 1.x.x but not 2.0.0', () {
      final c = CaretConstraint(SemanticVersion.parse('1.2.3'));
      expect(c.allows(SemanticVersion.parse('1.2.3')), true);
      expect(c.allows(SemanticVersion.parse('1.9.9')), true);
      expect(c.allows(SemanticVersion.parse('2.0.0')), false);
      expect(c.allows(SemanticVersion.parse('1.2.2')), false);
    });

    test('^0.2.3 allows 0.2.x but not 0.3.0', () {
      final c = CaretConstraint(SemanticVersion.parse('0.2.3'));
      expect(c.allows(SemanticVersion.parse('0.2.3')), true);
      expect(c.allows(SemanticVersion.parse('0.2.9')), true);
      expect(c.allows(SemanticVersion.parse('0.3.0')), false);
    });

    test('^0.0.3 allows only 0.0.3', () {
      final c = CaretConstraint(SemanticVersion.parse('0.0.3'));
      expect(c.allows(SemanticVersion.parse('0.0.3')), true);
      expect(c.allows(SemanticVersion.parse('0.0.4')), false);
    });
  });

  group('TildeConstraint', () {
    test('~1.2.3 allows 1.2.x but not 1.3.0', () {
      final c = TildeConstraint(SemanticVersion.parse('1.2.3'));
      expect(c.allows(SemanticVersion.parse('1.2.3')), true);
      expect(c.allows(SemanticVersion.parse('1.2.9')), true);
      expect(c.allows(SemanticVersion.parse('1.3.0')), false);
      expect(c.allows(SemanticVersion.parse('1.2.2')), false);
    });

    test('~0.1.0 allows 0.1.x but not 0.2.0', () {
      final c = TildeConstraint(SemanticVersion.parse('0.1.0'));
      expect(c.allows(SemanticVersion.parse('0.1.0')), true);
      expect(c.allows(SemanticVersion.parse('0.1.5')), true);
      expect(c.allows(SemanticVersion.parse('0.2.0')), false);
    });
  });

  group('VersionUnion', () {
    test('allows version in any constituent range', () {
      final union = VersionUnion([
        VersionRange.exact(SemanticVersion.parse('1.0.0')),
        VersionRange.exact(SemanticVersion.parse('2.0.0')),
      ]);
      expect(union.allows(SemanticVersion.parse('1.0.0')), true);
      expect(union.allows(SemanticVersion.parse('2.0.0')), true);
      expect(union.allows(SemanticVersion.parse('1.5.0')), false);
    });

    test('isEmpty when all ranges are empty', () {
      final union = VersionUnion([]);
      expect(union.isEmpty, true);
    });

    test('isAny when any range is any', () {
      final union = VersionUnion([const VersionRange()]);
      expect(union.isAny, true);
    });

    test('intersect with range produces filtered union', () {
      final union = VersionUnion([
        VersionRange(
          min: SemanticVersion.parse('1.0.0'),
          max: SemanticVersion.parse('2.0.0'),
        ),
        VersionRange(
          min: SemanticVersion.parse('3.0.0'),
          max: SemanticVersion.parse('4.0.0'),
        ),
      ]);
      final range = VersionRange(
        min: SemanticVersion.parse('1.5.0'),
        max: SemanticVersion.parse('3.5.0'),
      );
      final result = union.intersect(range);
      expect(result.allows(SemanticVersion.parse('1.5.0')), true);
      expect(result.allows(SemanticVersion.parse('3.2.0')), true);
      expect(result.allows(SemanticVersion.parse('1.0.0')), false);
      expect(result.allows(SemanticVersion.parse('3.8.0')), false);
    });

    test('union with range adds to ranges', () {
      final union = VersionUnion([
        VersionRange.exact(SemanticVersion.parse('1.0.0')),
      ]);
      final result = union.union(
        VersionRange.exact(SemanticVersion.parse('2.0.0')),
      );
      expect(result, isA<VersionUnion>());
      expect(result.allows(SemanticVersion.parse('2.0.0')), true);
    });

    test('toString joins ranges with ||', () {
      final union = VersionUnion([
        VersionRange.exact(SemanticVersion.parse('1.0.0')),
        VersionRange.exact(SemanticVersion.parse('2.0.0')),
      ]);
      expect(union.toString(), contains('||'));
    });
  });

  group('EmptyConstraint', () {
    test('allows nothing', () {
      const empty = EmptyConstraint();
      expect(empty.allows(SemanticVersion.parse('1.0.0')), false);
      expect(empty.isEmpty, true);
      expect(empty.isAny, false);
    });

    test('intersect returns self', () {
      const empty = EmptyConstraint();
      final result = empty.intersect(const VersionRange());
      expect(result, isA<EmptyConstraint>());
    });

    test('union returns other', () {
      const empty = EmptyConstraint();
      final range = VersionRange.exact(SemanticVersion.parse('1.0.0'));
      final result = empty.union(range);
      expect(result.allows(SemanticVersion.parse('1.0.0')), true);
    });

    test('toString returns <empty>', () {
      const empty = EmptyConstraint();
      expect(empty.toString(), '<empty>');
    });
  });
}
