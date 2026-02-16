/// Parameter definitions for skill inputs and outputs.
library;

/// A parameter definition for skill inputs.
class Parameter {
  Parameter({
    required this.name,
    required this.type,
    this.description,
    this.required = true,
    this.defaultValue,
    this.constraints = const {},
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  /// Parameter name.
  final String name;

  /// Parameter type.
  final ParameterType type;

  /// Parameter description.
  final String? description;

  /// Whether the parameter is required.
  final bool required;

  /// Default value.
  final dynamic defaultValue;

  /// Validation constraints.
  final Map<String, dynamic> constraints;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  /// Validate value type.
  String? validateType(dynamic value) {
    if (value == null) return null;

    switch (type) {
      case ParameterType.string:
        if (value is! String) return '$name must be a string';
      case ParameterType.number:
        if (value is! num) return '$name must be a number';
      case ParameterType.integer:
        if (value is! int) return '$name must be an integer';
      case ParameterType.boolean:
        if (value is! bool) return '$name must be a boolean';
      case ParameterType.array:
        if (value is! List) return '$name must be an array';
      case ParameterType.object:
        if (value is! Map) return '$name must be an object';
      case ParameterType.any:
        break;
    }
    return null;
  }

  /// Validate constraints.
  List<String> validateConstraints(dynamic value) {
    final errors = <String>[];
    if (value == null) return errors;

    // String constraints
    if (value is String) {
      final minLength = constraints['minLength'] as int?;
      if (minLength != null && value.length < minLength) {
        errors.add('$name must be at least $minLength characters');
      }

      final maxLength = constraints['maxLength'] as int?;
      if (maxLength != null && value.length > maxLength) {
        errors.add('$name must be at most $maxLength characters');
      }

      final pattern = constraints['pattern'] as String?;
      if (pattern != null && !RegExp(pattern).hasMatch(value)) {
        errors.add('$name does not match required pattern');
      }

      final enumValues = constraints['enum'] as List<dynamic>?;
      if (enumValues != null && !enumValues.contains(value)) {
        errors.add('$name must be one of: ${enumValues.join(', ')}');
      }
    }

    // Number constraints
    if (value is num) {
      final minimum = constraints['minimum'] as num?;
      if (minimum != null && value < minimum) {
        errors.add('$name must be at least $minimum');
      }

      final maximum = constraints['maximum'] as num?;
      if (maximum != null && value > maximum) {
        errors.add('$name must be at most $maximum');
      }

      final multipleOf = constraints['multipleOf'] as num?;
      if (multipleOf != null && value % multipleOf != 0) {
        errors.add('$name must be a multiple of $multipleOf');
      }
    }

    // Array constraints
    if (value is List) {
      final minItems = constraints['minItems'] as int?;
      if (minItems != null && value.length < minItems) {
        errors.add('$name must have at least $minItems items');
      }

      final maxItems = constraints['maxItems'] as int?;
      if (maxItems != null && value.length > maxItems) {
        errors.add('$name must have at most $maxItems items');
      }

      final uniqueItems = constraints['uniqueItems'] as bool?;
      if (uniqueItems == true && value.toSet().length != value.length) {
        errors.add('$name must have unique items');
      }
    }

    return errors;
  }

  /// Create from JSON.
  factory Parameter.fromJson(Map<String, dynamic> json) {
    return Parameter(
      name: json['name'] as String? ?? '',
      type: ParameterType.fromString(json['type'] as String? ?? 'any'),
      description: json['description'] as String?,
      required: json['required'] as bool? ?? true,
      defaultValue: json['default'],
      constraints: json['constraints'] as Map<String, dynamic>? ?? {},
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        if (description != null) 'description': description,
        'required': required,
        if (defaultValue != null) 'default': defaultValue,
        if (constraints.isNotEmpty) 'constraints': constraints,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  @override
  String toString() => 'Parameter($name: ${type.name})';
}

/// Parameter types.
enum ParameterType {
  /// String value.
  string,

  /// Numeric value (int or double).
  number,

  /// Integer value.
  integer,

  /// Boolean value.
  boolean,

  /// Array/list value.
  array,

  /// Object/map value.
  object,

  /// Any type.
  any;

  static ParameterType fromString(String value) {
    return ParameterType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ParameterType.any,
    );
  }
}
