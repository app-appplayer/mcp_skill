/// Ids made in quick succession must differ: a repeated id makes a store
/// replace the earlier record without an error.
library;

import 'package:mcp_skill/src/id_generator.dart';
import 'package:test/test.dart';

void main() {
  test('generateId gives distinct ids in a tight loop', () {
    final ids = {for (var i = 0; i < 5000; i++) generateId('claim')};
    expect(ids, hasLength(5000));
  });

  test('generateId keeps the prefix_digits_digits shape', () {
    expect(generateId('run'), matches(RegExp(r'^run_\d+_\d+$')));
  });
}
