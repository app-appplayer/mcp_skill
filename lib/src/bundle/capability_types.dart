/// Capability type definitions for skill bundles.
library;

/// Port types that a skill can require.
enum PortType { llm, mcp, knowledge, factGraph }

/// A specific port requirement.
class PortRequirement {
  final PortType type;
  final bool required;
  final String? minVersion;
  final List<String>? features;

  const PortRequirement({
    required this.type,
    this.required = true,
    this.minVersion,
    this.features,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'required': required,
        if (minVersion != null) 'minVersion': minVersion,
        if (features != null) 'features': features,
      };

  factory PortRequirement.fromJson(Map<String, dynamic> json) =>
      PortRequirement(
        type: PortType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => PortType.mcp,
        ),
        required: json['required'] as bool? ?? true,
        minVersion: json['minVersion'] as String?,
        features: (json['features'] as List<dynamic>?)?.cast<String>(),
      );
}

/// A named capability a skill provides.
class SkillCapability {
  final String name;
  final String? description;
  final Map<String, dynamic>? parameters;

  const SkillCapability({
    required this.name,
    this.description,
    this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (parameters != null) 'parameters': parameters,
      };

  factory SkillCapability.fromJson(Map<String, dynamic> json) =>
      SkillCapability(
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        parameters: json['parameters'] as Map<String, dynamic>?,
      );
}

/// Capabilities a skill provides.
class ProvidedCapabilities {
  final List<SkillCapability> capabilities;
  final List<String> tags;

  const ProvidedCapabilities({
    this.capabilities = const [],
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'capabilities': capabilities.map((c) => c.toJson()).toList(),
        'tags': tags,
      };

  factory ProvidedCapabilities.fromJson(Map<String, dynamic> json) =>
      ProvidedCapabilities(
        capabilities: (json['capabilities'] as List<dynamic>?)
                ?.map(
                    (e) => SkillCapability.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

/// Capabilities a skill requires.
class RequiredCapabilities {
  final List<PortRequirement> ports;
  final List<String> skills;

  const RequiredCapabilities({
    this.ports = const [],
    this.skills = const [],
  });

  Map<String, dynamic> toJson() => {
        'ports': ports.map((p) => p.toJson()).toList(),
        'skills': skills,
      };

  factory RequiredCapabilities.fromJson(Map<String, dynamic> json) =>
      RequiredCapabilities(
        ports: (json['ports'] as List<dynamic>?)
                ?.map(
                    (e) => PortRequirement.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        skills: (json['skills'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

/// Permission model for skill execution.
class PermissionCapabilities {
  final List<PortPermission> portPermissions;
  final List<DataPermission> dataPermissions;

  const PermissionCapabilities({
    this.portPermissions = const [],
    this.dataPermissions = const [],
  });

  Map<String, dynamic> toJson() => {
        'portPermissions':
            portPermissions.map((p) => p.toJson()).toList(),
        'dataPermissions':
            dataPermissions.map((p) => p.toJson()).toList(),
      };

  factory PermissionCapabilities.fromJson(Map<String, dynamic> json) =>
      PermissionCapabilities(
        portPermissions: (json['portPermissions'] as List<dynamic>?)
                ?.map(
                    (e) => PortPermission.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        dataPermissions: (json['dataPermissions'] as List<dynamic>?)
                ?.map(
                    (e) => DataPermission.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Permission for a port operation.
class PortPermission {
  final PortType port;
  final List<String> operations;
  final bool readOnly;

  const PortPermission({
    required this.port,
    this.operations = const [],
    this.readOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'port': port.name,
        'operations': operations,
        'readOnly': readOnly,
      };

  factory PortPermission.fromJson(Map<String, dynamic> json) =>
      PortPermission(
        port: PortType.values.firstWhere(
          (e) => e.name == json['port'],
          orElse: () => PortType.mcp,
        ),
        operations:
            (json['operations'] as List<dynamic>?)?.cast<String>() ?? [],
        readOnly: json['readOnly'] as bool? ?? false,
      );
}

/// Permission for data access.
class DataPermission {
  final String scope;
  final List<String> operations;

  const DataPermission({
    required this.scope,
    this.operations = const [],
  });

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'operations': operations,
      };

  factory DataPermission.fromJson(Map<String, dynamic> json) =>
      DataPermission(
        scope: json['scope'] as String? ?? '',
        operations:
            (json['operations'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}
