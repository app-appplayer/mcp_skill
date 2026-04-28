import 'package:test/test.dart';
import 'package:mcp_skill/src/bundle/permission_enforcer.dart';
import 'package:mcp_skill/src/bundle/capability_types.dart';

void main() {
  group('PermissionEnforcer', () {
    group('isPortOperationAllowed', () {
      test('allows operation when no permissions are configured', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(),
        );

        expect(enforcer.isPortOperationAllowed(PortType.llm, 'complete'),
            isTrue);
      });

      test('allows operation when port has no restrictions', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.llm),
            ],
          ),
        );

        expect(enforcer.isPortOperationAllowed(PortType.llm, 'complete'),
            isTrue);
      });

      test('allows read operation on readOnly port', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'read'),
          isTrue,
        );
        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'query'),
          isTrue,
        );
      });

      test('blocks write operations on readOnly port', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'write'),
          isFalse,
        );
      });

      test('blocks create on readOnly port', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'create'),
          isFalse,
        );
      });

      test('blocks update on readOnly port', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'update'),
          isFalse,
        );
      });

      test('blocks delete on readOnly port', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'delete'),
          isFalse,
        );
      });

      test('blocks put on readOnly port', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'put'),
          isFalse,
        );
      });

      test('blocks post on readOnly port', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'post'),
          isFalse,
        );
      });

      test('blocks patch on readOnly port', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'patch'),
          isFalse,
        );
      });

      test('write operation detection is case-insensitive', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'WRITE'),
          isFalse,
        );
        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'Delete'),
          isFalse,
        );
        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'CREATE'),
          isFalse,
        );
      });

      test('allows operation when it is in the operations whitelist', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(
                port: PortType.llm,
                operations: ['complete', 'embed'],
              ),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.llm, 'complete'),
          isTrue,
        );
        expect(
          enforcer.isPortOperationAllowed(PortType.llm, 'embed'),
          isTrue,
        );
      });

      test('blocks operation when it is not in the operations whitelist', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(
                port: PortType.llm,
                operations: ['complete'],
              ),
            ],
          ),
        );

        expect(
          enforcer.isPortOperationAllowed(PortType.llm, 'embed'),
          isFalse,
        );
      });

      test('allows operation on port that has no matching permission entry',
          () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.llm, operations: ['complete']),
            ],
          ),
        );

        // mcp has no permission entry, so it defaults to allowed
        expect(
          enforcer.isPortOperationAllowed(PortType.mcp, 'callTool'),
          isTrue,
        );
      });

      test('readOnly check takes precedence over empty operations list', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(
                port: PortType.factGraph,
                readOnly: true,
                operations: [],
              ),
            ],
          ),
        );

        // readOnly blocks write even when operations list is empty (no whitelist)
        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'write'),
          isFalse,
        );
        expect(
          enforcer.isPortOperationAllowed(PortType.factGraph, 'read'),
          isTrue,
        );
      });
    });

    group('isDataAccessAllowed', () {
      test('allows access when no data permissions are configured', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(),
        );

        expect(enforcer.isDataAccessAllowed('profile', 'read'), isTrue);
      });

      test('allows access when scope matches and operations list is empty',
          () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            dataPermissions: [
              DataPermission(scope: 'profile'),
            ],
          ),
        );

        expect(enforcer.isDataAccessAllowed('profile', 'read'), isTrue);
        expect(enforcer.isDataAccessAllowed('profile', 'write'), isTrue);
      });

      test('allows access when operation is in the allowed list', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            dataPermissions: [
              DataPermission(scope: 'profile', operations: ['read', 'list']),
            ],
          ),
        );

        expect(enforcer.isDataAccessAllowed('profile', 'read'), isTrue);
        expect(enforcer.isDataAccessAllowed('profile', 'list'), isTrue);
      });

      test('blocks access when operation is not in the allowed list', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            dataPermissions: [
              DataPermission(scope: 'profile', operations: ['read']),
            ],
          ),
        );

        expect(enforcer.isDataAccessAllowed('profile', 'write'), isFalse);
      });

      test('allows access on scope that has no matching permission entry', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            dataPermissions: [
              DataPermission(scope: 'profile', operations: ['read']),
            ],
          ),
        );

        // 'workspace' scope has no entry, so defaults to allowed
        expect(enforcer.isDataAccessAllowed('workspace', 'write'), isTrue);
      });

      test('handles multiple data permission scopes', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            dataPermissions: [
              DataPermission(scope: 'profile', operations: ['read']),
              DataPermission(
                  scope: 'workspace', operations: ['read', 'write']),
            ],
          ),
        );

        expect(enforcer.isDataAccessAllowed('profile', 'read'), isTrue);
        expect(enforcer.isDataAccessAllowed('profile', 'write'), isFalse);
        expect(enforcer.isDataAccessAllowed('workspace', 'write'), isTrue);
      });
    });

    group('enforcePortOperation', () {
      test('does not throw when operation is allowed', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(),
        );

        expect(
          () => enforcer.enforcePortOperation(PortType.llm, 'complete'),
          returnsNormally,
        );
      });

      test('throws PermissionException when operation is denied', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        expect(
          () => enforcer.enforcePortOperation(PortType.factGraph, 'write'),
          throwsA(isA<PermissionException>()),
        );
      });

      test('PermissionException message contains port and operation info', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        );

        try {
          enforcer.enforcePortOperation(PortType.factGraph, 'delete');
          fail('Expected PermissionException');
        } on PermissionException catch (e) {
          expect(e.message, contains('factGraph'));
          expect(e.message, contains('delete'));
          expect(e.toString(), contains('PermissionException'));
        }
      });

      test('throws when operation not in whitelist', () {
        final enforcer = PermissionEnforcer(
          const PermissionCapabilities(
            portPermissions: [
              PortPermission(
                port: PortType.llm,
                operations: ['complete'],
              ),
            ],
          ),
        );

        expect(
          () => enforcer.enforcePortOperation(PortType.llm, 'embed'),
          throwsA(isA<PermissionException>()),
        );
      });
    });
  });

  group('PermissionException', () {
    test('stores message', () {
      final exception = PermissionException('test message');
      expect(exception.message, equals('test message'));
    });

    test('toString includes prefix and message', () {
      final exception = PermissionException('access denied');
      expect(exception.toString(), equals('PermissionException: access denied'));
    });
  });
}
