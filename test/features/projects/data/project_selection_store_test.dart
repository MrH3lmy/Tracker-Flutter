import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = SharedPreferencesProjectSelectionStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reads null when nothing has been stored for that user', () async {
    expect(await store.readSelectedProjectId(1), isNull);
  });

  test('round-trips a written value', () async {
    await store.writeSelectedProjectId(1, 42);
    expect(await store.readSelectedProjectId(1), 42);
  });

  test('is namespaced per user id', () async {
    await store.writeSelectedProjectId(1, 42);
    await store.writeSelectedProjectId(2, 7);

    expect(await store.readSelectedProjectId(1), 42);
    expect(await store.readSelectedProjectId(2), 7);
  });

  test('clear removes only that user\'s value', () async {
    await store.writeSelectedProjectId(1, 42);
    await store.writeSelectedProjectId(2, 7);

    await store.clearSelectedProjectId(1);

    expect(await store.readSelectedProjectId(1), isNull);
    expect(await store.readSelectedProjectId(2), 7);
  });

  test('overwriting a value replaces the previous one', () async {
    await store.writeSelectedProjectId(1, 42);
    await store.writeSelectedProjectId(1, 43);

    expect(await store.readSelectedProjectId(1), 43);
  });
}
