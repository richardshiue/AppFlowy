import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('create a popover', (tester) async {
    await tester.pumpWidget(
      PopoverTestWidget(
        child: Popover(
          triggerActions: PopoverTriggerFlags.click,
          child: TextButton(
            child: const Text("AppFlowy"),
            onPressed: () {},
          ),
          popupBuilder: (context) => const SizedBox(height: 30, width: 30),
        ),
      ),
    );

    // press the button
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    // the popover should appear
    expect(find.byType(PopoverContainer), findsOneWidget);
  });

  testWidgets('dismiss the popover with esc', (tester) async {
    await tester.pumpWidget(
      PopoverTestWidget(
        child: Popover(
          triggerActions: PopoverTriggerFlags.click,
          child: TextButton(
            child: const Text("AppFlowy"),
            onPressed: () {},
          ),
          popupBuilder: (context) => const SizedBox(height: 30, width: 30),
        ),
      ),
    );

    // tap button
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.byType(PopoverContainer), findsOneWidget);

    // press escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // popover is dismissed
    expect(find.byType(PopoverContainer), findsNothing);
  });

  testWidgets('focus changes', (tester) async {
    await tester.pumpWidget(
      PopoverTestWidget(
        child: Popover(
          triggerActions: PopoverTriggerFlags.click,
          child: TextButton(
            child: const Text("AppFlowy"),
            onPressed: () {},
          ),
          popupBuilder: (context) => Focus(
            onKey: (node, event) {
              if (event is RawKeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: const Material(child: TextField(autofocus: true)),
          ),
        ),
      ),
    );

    // tap button
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.byType(PopoverContainer), findsOneWidget);

    // press escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // focus should absorb the escape and the popover should persist
    expect(find.byType(PopoverContainer), findsOneWidget);
  });
}

@visibleForTesting
class PopoverTestWidget extends StatelessWidget {
  final Widget child;
  const PopoverTestWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Popover Test",
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }
}
