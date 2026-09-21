import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vohk_app/widgets/responsive_content.dart';

void main() {
  Widget app(double maxWidth) {
    return MaterialApp(
      home: Scaffold(
        body: ResponsiveContent(
          maxWidth: maxWidth,
          child: const SizedBox(key: Key('content'), width: double.infinity, height: double.infinity),
        ),
      ),
    );
  }

  testWidgets('keeps the child at full width on phones', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(900));

    expect(tester.getSize(find.byKey(const Key('content'))).width, 500);
  });

  testWidgets('centers and constrains the child on tablets', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(900));

    expect(tester.getSize(find.byKey(const Key('content'))).width, 900);
    expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, 150);
  });
}
