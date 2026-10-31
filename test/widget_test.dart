// Replaces the default counter test that `flutter create` generates.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recipes use known elements, sorted keys, and are all reachable', () {
    final data = jsonDecode(File('assets/recipes.json').readAsStringSync())
        as Map<String, dynamic>;
    final base = List<String>.from(data['base'] as List);
    final elements = (data['elements'] as Map<String, dynamic>).keys.toSet();
    final recipes = Map<String, String>.from(data['recipes'] as Map);

    final reachable = <String>{...base};
    var changed = true;
    while (changed) {
      changed = false;
      recipes.forEach((key, result) {
        final parts = key.split('+');
        expect(parts[0].compareTo(parts[1]) <= 0, isTrue, reason: key);
        expect(elements.contains(parts[0]) && elements.contains(parts[1]), isTrue,
            reason: key);
        expect(elements.contains(result), isTrue, reason: result);
        if (reachable.contains(parts[0]) &&
            reachable.contains(parts[1]) &&
            reachable.add(result)) {
          changed = true;
        }
      });
    }
    expect(reachable, elements);
  });
}
