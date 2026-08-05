import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/utils/breakpoints.dart';

void main() {
  Widget hostAt(double width, ValueChanged<AppBreakpoint> onBuild) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Builder(
        builder: (context) {
          onBuild(AppBreakpoint.of(context));
          return const SizedBox.shrink();
        },
      ),
    );
  }

  testWidgets('classifies phone widths as compact', (tester) async {
    AppBreakpoint? result;
    await tester.pumpWidget(hostAt(400, (b) => result = b));
    expect(result, AppBreakpoint.compact);
  });

  testWidgets('classifies tablet widths as medium', (tester) async {
    AppBreakpoint? result;
    await tester.pumpWidget(hostAt(700, (b) => result = b));
    expect(result, AppBreakpoint.medium);
  });

  testWidgets('classifies desktop widths as expanded', (tester) async {
    AppBreakpoint? result;
    await tester.pumpWidget(hostAt(1200, (b) => result = b));
    expect(result, AppBreakpoint.expanded);
  });
}
