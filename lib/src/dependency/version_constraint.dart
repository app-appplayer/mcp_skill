/// Version Constraint - Semantic versioning and constraint parsing.
///
/// Provides semantic version parsing and constraint evaluation following
/// the PubGrub specification for dependency resolution.
library;

// =============================================================================
// Semantic Version
// =============================================================================

/// Semantic version following SemVer 2.0 specification.
class SemanticVersion implements Comparable<SemanticVersion> {
  /// Major version number.
  final int major;

  /// Minor version number.
  final int minor;

  /// Patch version number.
  final int patch;

  /// Pre-release identifiers.
  final List<String> preRelease;

  /// Build metadata.
  final String? build;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease = const [],
    this.build,
  });

  /// Zero version (0.0.0).
  static const zero = SemanticVersion(major: 0, minor: 0, patch: 0);

  /// Parse a version string.
  factory SemanticVersion.parse(String version) {
    final match = _versionRegex.firstMatch(version.trim());
    if (match == null) {
      throw FormatException('Invalid version format: $version');
    }

    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);
    final preRelease = match.group(4)?.split('.') ?? const [];
    final build = match.group(5);

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: preRelease,
      build: build,
    );
  }

  static final _versionRegex = RegExp(
    r'^(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z0-9.-]+))?(?:\+([a-zA-Z0-9.-]+))?$',
  );

  /// Whether this is a pre-release version.
  bool get isPrerelease => preRelease.isNotEmpty;

  /// Next major version.
  SemanticVersion nextMajor() => SemanticVersion(
        major: major + 1,
        minor: 0,
        patch: 0,
      );

  /// Next minor version.
  SemanticVersion nextMinor() => SemanticVersion(
        major: major,
        minor: minor + 1,
        patch: 0,
      );

  /// Next patch version.
  SemanticVersion nextPatch() => SemanticVersion(
        major: major,
        minor: minor,
        patch: patch + 1,
      );

  /// Next breaking version for caret constraint.
  SemanticVersion nextBreaking() {
    if (major == 0) {
      if (minor == 0) {
        return SemanticVersion(major: 0, minor: 0, patch: patch + 1);
      }
      return SemanticVersion(major: 0, minor: minor + 1, patch: 0);
    }
    return nextMajor();
  }

  @override
  int compareTo(SemanticVersion other) {
    // Compare major.minor.patch
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // Pre-release versions have lower precedence
    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;

    // Compare pre-release identifiers
    final maxLen =
        preRelease.length > other.preRelease.length ? preRelease.length : other.preRelease.length;
    for (var i = 0; i < maxLen; i++) {
      if (i >= preRelease.length) return -1;
      if (i >= other.preRelease.length) return 1;

      final a = preRelease[i];
      final b = other.preRelease[i];

      final aNum = int.tryParse(a);
      final bNum = int.tryParse(b);

      if (aNum != null && bNum != null) {
        if (aNum != bNum) return aNum.compareTo(bNum);
      } else if (aNum != null) {
        return -1; // Numbers sort before strings
      } else if (bNum != null) {
        return 1;
      } else {
        final cmp = a.compareTo(b);
        if (cmp != 0) return cmp;
      }
    }

    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch &&
      _listEquals(preRelease, other.preRelease);

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  String toString() {
    final buffer = StringBuffer('$major.$minor.$patch');
    if (preRelease.isNotEmpty) {
      buffer.write('-${preRelease.join('.')}');
    }
    if (build != null) {
      buffer.write('+$build');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'major': major,
        'minor': minor,
        'patch': patch,
        if (preRelease.isNotEmpty) 'preRelease': preRelease,
        if (build != null) 'build': build,
      };

  factory SemanticVersion.fromJson(Map<String, dynamic> json) => SemanticVersion(
        major: json['major'] as int,
        minor: json['minor'] as int,
        patch: json['patch'] as int,
        preRelease:
            (json['preRelease'] as List<dynamic>?)?.cast<String>() ?? const [],
        build: json['build'] as String?,
      );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// =============================================================================
// Version Constraint
// =============================================================================

/// Abstract interface for version constraints.
abstract class VersionConstraint {
  const VersionConstraint();

  /// Check if a version satisfies this constraint.
  bool allows(SemanticVersion version);

  /// Intersect with another constraint.
  VersionConstraint intersect(VersionConstraint other);

  /// Union with another constraint.
  VersionConstraint union(VersionConstraint other);

  /// Whether this constraint allows no versions.
  bool get isEmpty;

  /// Whether this constraint allows any version.
  bool get isAny;

  /// Constraint that allows any version.
  static const any = VersionRange();

  /// Constraint that allows no versions.
  static const empty = EmptyConstraint();

  /// Parse a constraint string.
  factory VersionConstraint.parse(String constraint) {
    final trimmed = constraint.trim();

    if (trimmed.isEmpty || trimmed == '*' || trimmed == 'any') {
      return any;
    }

    // Check for union (||)
    if (trimmed.contains('||')) {
      final parts = trimmed.split('||').map((p) => p.trim()).toList();
      var result = VersionConstraint.parse(parts.first);
      for (var i = 1; i < parts.length; i++) {
        result = result.union(VersionConstraint.parse(parts[i]));
      }
      return result;
    }

    // Check for caret constraint
    if (trimmed.startsWith('^')) {
      return CaretConstraint(SemanticVersion.parse(trimmed.substring(1)));
    }

    // Check for tilde constraint
    if (trimmed.startsWith('~')) {
      return TildeConstraint(SemanticVersion.parse(trimmed.substring(1)));
    }

    // Check for range operators
    final rangeMatch = _rangeRegex.firstMatch(trimmed);
    if (rangeMatch != null) {
      SemanticVersion? min;
      SemanticVersion? max;
      var includeMin = true;
      var includeMax = true;

      // Parse the constraint parts
      final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();
      for (final part in parts) {
        if (part.startsWith('>=')) {
          min = SemanticVersion.parse(part.substring(2));
          includeMin = true;
        } else if (part.startsWith('>')) {
          min = SemanticVersion.parse(part.substring(1));
          includeMin = false;
        } else if (part.startsWith('<=')) {
          max = SemanticVersion.parse(part.substring(2));
          includeMax = true;
        } else if (part.startsWith('<')) {
          max = SemanticVersion.parse(part.substring(1));
          includeMax = false;
        } else if (part.startsWith('=')) {
          final version = SemanticVersion.parse(part.substring(1));
          return VersionRange(
            min: version,
            max: version,
            includeMin: true,
            includeMax: true,
          );
        }
      }

      return VersionRange(
        min: min,
        max: max,
        includeMin: includeMin,
        includeMax: includeMax,
      );
    }

    // Exact version
    final version = SemanticVersion.parse(trimmed);
    return VersionRange(
      min: version,
      max: version,
      includeMin: true,
      includeMax: true,
    );
  }

  static final _rangeRegex = RegExp(r'[<>=]');
}

// =============================================================================
// Version Range
// =============================================================================

/// A range of versions.
class VersionRange extends VersionConstraint {
  /// Minimum version (null = no lower bound).
  final SemanticVersion? min;

  /// Maximum version (null = no upper bound).
  final SemanticVersion? max;

  /// Whether the minimum is inclusive.
  final bool includeMin;

  /// Whether the maximum is inclusive.
  final bool includeMax;

  const VersionRange({
    this.min,
    this.max,
    this.includeMin = true,
    this.includeMax = false,
  });

  /// Exact version constraint.
  factory VersionRange.exact(SemanticVersion version) => VersionRange(
        min: version,
        max: version,
        includeMin: true,
        includeMax: true,
      );

  @override
  bool get isEmpty {
    if (min == null || max == null) return false;
    final cmp = min!.compareTo(max!);
    if (cmp > 0) return true;
    if (cmp == 0) return !includeMin || !includeMax;
    return false;
  }

  @override
  bool get isAny => min == null && max == null;

  @override
  bool allows(SemanticVersion version) {
    if (min != null) {
      final cmp = version.compareTo(min!);
      if (cmp < 0) return false;
      if (cmp == 0 && !includeMin) return false;
    }
    if (max != null) {
      final cmp = version.compareTo(max!);
      if (cmp > 0) return false;
      if (cmp == 0 && !includeMax) return false;
    }
    return true;
  }

  @override
  VersionConstraint intersect(VersionConstraint other) {
    if (other is VersionRange) {
      SemanticVersion? newMin;
      bool newIncludeMin;
      if (min == null) {
        newMin = other.min;
        newIncludeMin = other.includeMin;
      } else if (other.min == null) {
        newMin = min;
        newIncludeMin = includeMin;
      } else {
        final cmp = min!.compareTo(other.min!);
        if (cmp < 0) {
          newMin = other.min;
          newIncludeMin = other.includeMin;
        } else if (cmp > 0) {
          newMin = min;
          newIncludeMin = includeMin;
        } else {
          newMin = min;
          newIncludeMin = includeMin && other.includeMin;
        }
      }

      SemanticVersion? newMax;
      bool newIncludeMax;
      if (max == null) {
        newMax = other.max;
        newIncludeMax = other.includeMax;
      } else if (other.max == null) {
        newMax = max;
        newIncludeMax = includeMax;
      } else {
        final cmp = max!.compareTo(other.max!);
        if (cmp > 0) {
          newMax = other.max;
          newIncludeMax = other.includeMax;
        } else if (cmp < 0) {
          newMax = max;
          newIncludeMax = includeMax;
        } else {
          newMax = max;
          newIncludeMax = includeMax && other.includeMax;
        }
      }

      final range = VersionRange(
        min: newMin,
        max: newMax,
        includeMin: newIncludeMin,
        includeMax: newIncludeMax,
      );

      return range.isEmpty ? VersionConstraint.empty : range;
    }

    if (other is VersionUnion) {
      return other.intersect(this);
    }

    if (other is EmptyConstraint) {
      return VersionConstraint.empty;
    }

    return VersionConstraint.empty;
  }

  @override
  VersionConstraint union(VersionConstraint other) {
    if (other is VersionRange) {
      // Check for overlap or adjacency
      if (_allowsAll(other) || other._allowsAll(this)) {
        return _allowsAll(other) ? this : other;
      }

      // Check if ranges are adjacent
      if (_isAdjacent(other)) {
        return VersionRange(
          min: _lowerMin(other),
          max: _higherMax(other),
          includeMin: _lowerIncludeMin(other),
          includeMax: _higherIncludeMax(other),
        );
      }

      return VersionUnion([this, other]);
    }

    if (other is VersionUnion) {
      return other.union(this);
    }

    if (other is EmptyConstraint) {
      return this;
    }

    return VersionUnion([this]);
  }

  bool _allowsAll(VersionRange other) {
    if (min != null && other.min != null) {
      final cmp = min!.compareTo(other.min!);
      if (cmp > 0) return false;
      if (cmp == 0 && !includeMin && other.includeMin) return false;
    } else if (min != null && other.min == null) {
      return false;
    }

    if (max != null && other.max != null) {
      final cmp = max!.compareTo(other.max!);
      if (cmp < 0) return false;
      if (cmp == 0 && !includeMax && other.includeMax) return false;
    } else if (max != null && other.max == null) {
      return false;
    }

    return true;
  }

  bool _isAdjacent(VersionRange other) {
    if (max != null && other.min != null) {
      final cmp = max!.compareTo(other.min!);
      if (cmp == 0) return includeMax || other.includeMin;
    }
    if (other.max != null && min != null) {
      final cmp = other.max!.compareTo(min!);
      if (cmp == 0) return other.includeMax || includeMin;
    }
    return false;
  }

  SemanticVersion? _lowerMin(VersionRange other) {
    if (min == null) return null;
    if (other.min == null) return null;
    return min!.compareTo(other.min!) <= 0 ? min : other.min;
  }

  SemanticVersion? _higherMax(VersionRange other) {
    if (max == null) return null;
    if (other.max == null) return null;
    return max!.compareTo(other.max!) >= 0 ? max : other.max;
  }

  bool _lowerIncludeMin(VersionRange other) {
    if (min == null) return true;
    if (other.min == null) return true;
    final cmp = min!.compareTo(other.min!);
    if (cmp < 0) return includeMin;
    if (cmp > 0) return other.includeMin;
    return includeMin || other.includeMin;
  }

  bool _higherIncludeMax(VersionRange other) {
    if (max == null) return true;
    if (other.max == null) return true;
    final cmp = max!.compareTo(other.max!);
    if (cmp > 0) return includeMax;
    if (cmp < 0) return other.includeMax;
    return includeMax || other.includeMax;
  }

  @override
  String toString() {
    if (isAny) return 'any';
    if (min != null && max != null && min == max) return min.toString();

    final parts = <String>[];
    if (min != null) {
      parts.add('${includeMin ? '>=' : '>'}$min');
    }
    if (max != null) {
      parts.add('${includeMax ? '<=' : '<'}$max');
    }
    return parts.join(' ');
  }
}

// =============================================================================
// Caret Constraint
// =============================================================================

/// Caret constraint (^x.y.z).
///
/// Allows changes that do not modify the left-most non-zero digit.
class CaretConstraint extends VersionRange {
  CaretConstraint(SemanticVersion version)
      : super(
          min: version,
          max: version.nextBreaking(),
          includeMin: true,
          includeMax: false,
        );
}

// =============================================================================
// Tilde Constraint
// =============================================================================

/// Tilde constraint (~x.y.z).
///
/// Allows patch-level changes.
class TildeConstraint extends VersionRange {
  TildeConstraint(SemanticVersion version)
      : super(
          min: version,
          max: version.nextMinor(),
          includeMin: true,
          includeMax: false,
        );
}

// =============================================================================
// Version Union
// =============================================================================

/// Union of multiple version ranges.
class VersionUnion extends VersionConstraint {
  /// Constituent ranges.
  final List<VersionRange> ranges;

  VersionUnion(this.ranges);

  @override
  bool get isEmpty => ranges.isEmpty || ranges.every((r) => r.isEmpty);

  @override
  bool get isAny => ranges.any((r) => r.isAny);

  @override
  bool allows(SemanticVersion version) =>
      ranges.any((range) => range.allows(version));

  @override
  VersionConstraint intersect(VersionConstraint other) {
    final results = <VersionRange>[];
    for (final range in ranges) {
      final intersected = range.intersect(other);
      if (intersected is VersionRange && !intersected.isEmpty) {
        results.add(intersected);
      } else if (intersected is VersionUnion) {
        results.addAll(intersected.ranges.where((r) => !r.isEmpty));
      }
    }
    if (results.isEmpty) return VersionConstraint.empty;
    if (results.length == 1) return results.first;
    return VersionUnion(results);
  }

  @override
  VersionConstraint union(VersionConstraint other) {
    if (other is VersionRange) {
      return VersionUnion([...ranges, other]);
    }
    if (other is VersionUnion) {
      return VersionUnion([...ranges, ...other.ranges]);
    }
    return this;
  }

  @override
  String toString() => ranges.join(' || ');
}

// =============================================================================
// Empty Constraint
// =============================================================================

/// Constraint that allows no versions.
class EmptyConstraint extends VersionConstraint {
  const EmptyConstraint();

  @override
  bool get isEmpty => true;

  @override
  bool get isAny => false;

  @override
  bool allows(SemanticVersion version) => false;

  @override
  VersionConstraint intersect(VersionConstraint other) => this;

  @override
  VersionConstraint union(VersionConstraint other) => other;

  @override
  String toString() => '<empty>';
}
