/// Permission enforcer for enforcing permission constraints during execution.
library;

import 'capability_types.dart';

/// Enforces permission constraints during skill execution.
class PermissionEnforcer {
  final PermissionCapabilities _permissions;

  PermissionEnforcer(this._permissions);

  /// Check if a port operation is allowed.
  bool isPortOperationAllowed(PortType port, String operation) {
    for (final perm in _permissions.portPermissions) {
      if (perm.port == port) {
        if (perm.readOnly && _isWriteOperation(operation)) return false;
        if (perm.operations.isNotEmpty &&
            !perm.operations.contains(operation)) {
          return false;
        }
        return true;
      }
    }
    // No explicit permission means allowed by default
    return true;
  }

  /// Check if a data scope is accessible.
  bool isDataAccessAllowed(String scope, String operation) {
    for (final perm in _permissions.dataPermissions) {
      if (perm.scope == scope) {
        if (perm.operations.isNotEmpty &&
            !perm.operations.contains(operation)) {
          return false;
        }
        return true;
      }
    }
    return true;
  }

  /// Enforce a port operation, throwing if not allowed.
  void enforcePortOperation(PortType port, String operation) {
    if (!isPortOperationAllowed(port, operation)) {
      throw PermissionException(
        'Port operation not allowed: ${port.name}.$operation',
      );
    }
  }

  /// Check if the operation is a write operation.
  bool _isWriteOperation(String operation) {
    const writeOps = {
      'write',
      'create',
      'update',
      'delete',
      'put',
      'post',
      'patch',
    };
    return writeOps.contains(operation.toLowerCase());
  }
}

/// Exception thrown when a permission check fails.
class PermissionException implements Exception {
  final String message;

  PermissionException(this.message);

  @override
  String toString() => 'PermissionException: $message';
}
