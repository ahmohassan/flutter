// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'semantics_tester.dart';

final List<String> results = <String>[];

Set<TestRoute> routes = HashSet<TestRoute>();

class TestRoute extends Route<String?> with LocalHistoryRoute<String?> {
  TestRoute(this.name);
  final String name;

  @override
  List<OverlayEntry> get overlayEntries => _entries;

  final List<OverlayEntry> _entries = <OverlayEntry>[];

  void log(String s) {
    results.add('$name: $s');
  }

  @override
  void install() {
    log('install');
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) => Container(),
      opaque: true,
    );
    _entries.add(entry);
    routes.add(this);
    super.install();
  }

  @override
  TickerFuture didPush() {
    log('didPush');
    return super.didPush();
  }

  @override
  void didAdd() {
    log('didAdd');
    super.didAdd();
  }

  @override
  void didReplace(Route<dynamic>? oldRoute) {
    expect(oldRoute, isA<TestRoute>());
    final TestRoute castRoute = oldRoute! as TestRoute;
    log('didReplace ${castRoute.name}');
    super.didReplace(castRoute);
  }

  @override
  bool didPop(String? result) {
    log('didPop $result');
    bool returnValue;
    if (returnValue = super.didPop(result))
      navigator!.finalizeRoute(this);
    return returnValue;
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    expect(nextRoute, isA<TestRoute>());
    final TestRoute castRoute = nextRoute as TestRoute;
    log('didPopNext ${castRoute.name}');
    super.didPopNext(castRoute);
  }

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    expect(nextRoute, anyOf(isNull, isA<TestRoute>()));
    final TestRoute? castRoute = nextRoute as TestRoute?;
    log('didChangeNext ${castRoute?.name}');
    super.didChangeNext(castRoute);
  }

  @override
  void dispose() {
    log('dispose');
    _entries.clear();
    routes.remove(this);
    super.dispose();
  }

}

Future<void> runNavigatorTest(
  WidgetTester tester,
  NavigatorState host,
  VoidCallback test,
  List<String> expectations, [
  List<String> expectationsAfterAnotherPump = const <String>[],
]) async {
  expect(host, isNotNull);
  test();
  expect(results, equals(expectations));
  results.clear();
  await tester.pump();
  expect(results, equals(expectationsAfterAnotherPump));
  results.clear();
}

void main() {
  testWidgets('Route settings', (WidgetTester tester) async {
    const RouteSettings settings = RouteSettings(name: 'A');
    expect(settings, hasOneLineDescription);
    final RouteSettings settings2 = settings.copyWith(name: 'B');
    expect(settings2.name, 'B');
  });

  testWidgets('Route settings arguments', (WidgetTester tester) async {
    const RouteSettings settings = RouteSettings(name: 'A');
    expect(settings.arguments, isNull);

    final Object arguments = Object();
    final RouteSettings settings2 = RouteSettings(name: 'A', arguments: arguments);
    expect(settings2.arguments, same(arguments));

    final RouteSettings settings3 = settings2.copyWith();
    expect(settings3.arguments, equals(arguments));

    final Object arguments2 = Object();
    final RouteSettings settings4 = settings2.copyWith(arguments: arguments2);
    expect(settings4.arguments, same(arguments2));
    expect(settings4.arguments, isNot(same(arguments)));
  });

  testWidgets('Route management - push, replace, pop sequence', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => TestRoute('initial'),
        ),
      ),
    );
    final NavigatorState host = navigatorKey.currentState!;
    await runNavigatorTest(
      tester,
      host,
      () { },
      <String>[
        'initial: install',
        'initial: didAdd',
        'initial: didChangeNext null',
      ],
    );
    late TestRoute second;
    await runNavigatorTest(
      tester,
      host,
      () { host.push(second = TestRoute('second')); },
      <String>[ // stack is: initial, second
        'second: install',
        'second: didPush',
        'second: didChangeNext null',
        'initial: didChangeNext second',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.push(TestRoute('third')); },
      <String>[ // stack is: initial, second, third
        'third: install',
        'third: didPush',
        'third: didChangeNext null',
        'second: didChangeNext third',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.replace(oldRoute: second, newRoute: TestRoute('two')); },
      <String>[ // stack is: initial, two, third
        'two: install',
        'two: didReplace second',
        'two: didChangeNext third',
        'initial: didChangeNext two',
        'second: dispose',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.pop('hello'); },
      <String>[ // stack is: initial, two
        'third: didPop hello',
        'two: didPopNext third',
      ],
      <String>[
        'third: dispose',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.pop('good bye'); },
      <String>[ // stack is: initial
        'two: didPop good bye',
        'initial: didPopNext two',
      ],
      <String>[
        'two: dispose',
      ],
    );
    await tester.pumpWidget(Container());
    expect(results, equals(<String>['initial: dispose']));
    expect(routes.isEmpty, isTrue);
    results.clear();
  });

  testWidgets('Route management - push, remove, pop', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => TestRoute('first'),
        ),
      ),
    );
    final NavigatorState host = navigatorKey.currentState!;
    await runNavigatorTest(
      tester,
      host,
      () { },
      <String>[
        'first: install',
        'first: didAdd',
        'first: didChangeNext null',
      ],
    );
    late TestRoute second;
    await runNavigatorTest(
      tester,
      host,
      () { host.push(second = TestRoute('second')); },
      <String>[
        'second: install',
        'second: didPush',
        'second: didChangeNext null',
        'first: didChangeNext second',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.push(TestRoute('third')); },
      <String>[
        'third: install',
        'third: didPush',
        'third: didChangeNext null',
        'second: didChangeNext third',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.removeRouteBelow(second); },
      <String>[
        'first: dispose',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.pop('good bye'); },
      <String>[
        'third: didPop good bye',
        'second: didPopNext third',
      ],
      <String>[
        'third: dispose',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.push(TestRoute('three')); },
      <String>[
        'three: install',
        'three: didPush',
        'three: didChangeNext null',
        'second: didChangeNext three',
      ],
    );
    late TestRoute four;
    await runNavigatorTest(
      tester,
      host,
      () { host.push(four = TestRoute('four')); },
      <String>[
        'four: install',
        'four: didPush',
        'four: didChangeNext null',
        'three: didChangeNext four',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.removeRouteBelow(four); },
      <String>[
        'second: didChangeNext four',
        'three: dispose',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.pop('the end'); },
      <String>[
        'four: didPop the end',
        'second: didPopNext four',
      ],
      <String>[
        'four: dispose',
      ],
    );
    await tester.pumpWidget(Container());
    expect(results, equals(<String>['second: dispose']));
    expect(routes.isEmpty, isTrue);
    results.clear();
  });

  testWidgets('Route management - push, replace, popUntil', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => TestRoute('A'),
        ),
      ),
    );
    final NavigatorState host = navigatorKey.currentState!;
    await runNavigatorTest(
      tester,
      host,
      () { },
      <String>[
        'A: install',
        'A: didAdd',
        'A: didChangeNext null',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.push(TestRoute('B')); },
      <String>[
        'B: install',
        'B: didPush',
        'B: didChangeNext null',
        'A: didChangeNext B',
      ],
    );
    late TestRoute routeC;
    await runNavigatorTest(
      tester,
      host,
      () { host.push(routeC = TestRoute('C')); },
      <String>[
        'C: install',
        'C: didPush',
        'C: didChangeNext null',
        'B: didChangeNext C',
      ],
    );
    expect(routeC.isActive, isTrue);
    late TestRoute routeB;
    await runNavigatorTest(
      tester,
      host,
      () { host.replaceRouteBelow(anchorRoute: routeC, newRoute: routeB = TestRoute('b')); },
      <String>[
        'b: install',
        'b: didReplace B',
        'b: didChangeNext C',
        'A: didChangeNext b',
        'B: dispose',
      ],
    );
    await runNavigatorTest(
      tester,
      host,
      () { host.popUntil((Route<dynamic> route) => route == routeB); },
      <String>[
        'C: didPop null',
        'b: didPopNext C',
      ],
      <String>[
        'C: dispose',
      ],
    );
    await tester.pumpWidget(Container());
    expect(results, equals(<String>['A: dispose', 'b: dispose']));
    expect(routes.isEmpty, isTrue);
    results.clear();
  });

  testWidgets('Route localHistory - popUntil', (WidgetTester tester) async {
    final TestRoute routeA = TestRoute('A');
    routeA.addLocalHistoryEntry(LocalHistoryEntry(
      onRemove: () { routeA.log('onRemove 0'); },
    ));
    routeA.addLocalHistoryEntry(LocalHistoryEntry(
      onRemove: () { routeA.log('onRemove 1'); },
    ));
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => routeA,
        ),
      ),
    );
    final NavigatorState host = navigatorKey.currentState!;
    await runNavigatorTest(
      tester,
      host,
      () { host.popUntil((Route<dynamic> route) => !route.willHandlePopInternally); },
      <String>[
        'A: install',
        'A: didAdd',
        'A: didChangeNext null',
        'A: didPop null',
        'A: onRemove 1',
        'A: didPop null',
        'A: onRemove 0',
      ],
    );

    await runNavigatorTest(
      tester,
      host,
      () { host.popUntil((Route<dynamic> route) => !route.willHandlePopInternally); },
      <String>[
      ],
    );
    await tester.pumpWidget(Container());
    expect(routes.isEmpty, isTrue);
    results.clear();
  });

  group('PageRouteObserver', () {
    test('calls correct listeners', () {
      final RouteObserver<PageRoute<dynamic>> observer = RouteObserver<PageRoute<dynamic>>();
      final MockRouteAware pageRouteAware1 = MockRouteAware();
      final MockPageRoute route1 = MockPageRoute();
      observer.subscribe(pageRouteAware1, route1);
      expect(pageRouteAware1.didPushCount, 1);

      final MockRouteAware pageRouteAware2 = MockRouteAware();
      final MockPageRoute route2 = MockPageRoute();
      observer.didPush(route2, route1);
      expect(pageRouteAware1.didPushNextCount, 1);

      observer.subscribe(pageRouteAware2, route2);
      expect(pageRouteAware2.didPushCount, 1);

      observer.didPop(route2, route1);
      expect(pageRouteAware2.didPopCount, 1);
      expect(pageRouteAware1.didPopNextCount, 1);
    });

    test('does not call listeners for non-PageRoute', () {
      final RouteObserver<PageRoute<dynamic>> observer = RouteObserver<PageRoute<dynamic>>();
      final MockRouteAware pageRouteAware = MockRouteAware();
      final MockPageRoute pageRoute = MockPageRoute();
      final MockRoute route = MockRoute();
      observer.subscribe(pageRouteAware, pageRoute);
      expect(pageRouteAware.didPushCount, 1);

      observer.didPush(route, pageRoute);
      observer.didPop(route, pageRoute);

      expect(pageRouteAware.didPushCount, 1);
      expect(pageRouteAware.didPopCount, 0);
    });

    test('does not call listeners when already subscribed', () {
      final RouteObserver<PageRoute<dynamic>> observer = RouteObserver<PageRoute<dynamic>>();
      final MockRouteAware pageRouteAware = MockRouteAware();
      final MockPageRoute pageRoute = MockPageRoute();
      observer.subscribe(pageRouteAware, pageRoute);
      observer.subscribe(pageRouteAware, pageRoute);
      expect(pageRouteAware.didPushCount, 1);
    });

    test('does not call listeners when unsubscribed', () {
      final RouteObserver<PageRoute<dynamic>> observer = RouteObserver<PageRoute<dynamic>>();
      final MockRouteAware pageRouteAware = MockRouteAware();
      final MockPageRoute pageRoute = MockPageRoute();
      final MockPageRoute nextPageRoute = MockPageRoute();
      observer.subscribe(pageRouteAware, pageRoute);
      observer.subscribe(pageRouteAware, nextPageRoute);
      expect(pageRouteAware.didPushCount, 2);

      observer.unsubscribe(pageRouteAware);

      observer.didPush(nextPageRoute, pageRoute);
      observer.didPop(nextPageRoute, pageRoute);

      expect(pageRouteAware.didPushCount, 2);
      expect(pageRouteAware.didPopCount, 0);
    });

    test('releases reference to route when unsubscribed', () {
      final RouteObserver<PageRoute<dynamic>> observer = RouteObserver<PageRoute<dynamic>>();
      final MockRouteAware pageRouteAware = MockRouteAware();
      final MockRouteAware page2RouteAware = MockRouteAware();
      final MockPageRoute pageRoute = MockPageRoute();
      final MockPageRoute nextPageRoute = MockPageRoute();
      observer.subscribe(pageRouteAware, pageRoute);
      observer.subscribe(pageRouteAware, nextPageRoute);
      observer.subscribe(page2RouteAware, pageRoute);
      observer.subscribe(page2RouteAware, nextPageRoute);
      expect(pageRouteAware.didPushCount, 2);
      expect(page2RouteAware.didPushCount, 2);

      expect(observer.debugObservingRoute(pageRoute), true);
      expect(observer.debugObservingRoute(nextPageRoute), true);

      observer.unsubscribe(pageRouteAware);

      expect(observer.debugObservingRoute(pageRoute), true);
      expect(observer.debugObservingRoute(nextPageRoute), true);

      observer.unsubscribe(page2RouteAware);

      expect(observer.debugObservingRoute(pageRoute), false);
      expect(observer.debugObservingRoute(nextPageRoute), false);
    });
  });

  testWidgets('Can autofocus a TextField nested in a Focus in a route.', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();

    final FocusNode focusNode = FocusNode(debugLabel: 'Test Node');
    await tester.pumpWidget(
      Material(
        child: MaterialApp(
          onGenerateRoute: (RouteSettings settings) {
            return PageRouteBuilder<void>(
              settings: settings,
              pageBuilder: (BuildContext context, Animation<double> input, Animation<double> out) {
                return Focus(
                  child: TextField(
                    autofocus: true,
                    focusNode: focusNode,
                    controller: controller,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(focusNode.hasPrimaryFocus, isTrue);
  });

  group('PageRouteBuilder', () {
    testWidgets('reverseTransitionDuration defaults to 300ms', (WidgetTester tester) async {
      // Default PageRouteBuilder reverse transition duration should be 300ms.
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (RouteSettings settings) {
            return MaterialPageRoute<dynamic>(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      PageRouteBuilder<void>(
                        settings: settings,
                        pageBuilder: (BuildContext context, Animation<double> input, Animation<double> out) {
                          return const Text('Page Two');
                        },
                      ),
                    );
                  },
                  child: const Text('Open page'),
                );
              },
            );
          },
        ),
      );

      // Open the new route.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('Open page'), findsNothing);
      expect(find.text('Page Two'), findsOneWidget);

      // Pop the new route.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      expect(find.text('Page Two'), findsOneWidget);

      // Text('Page Two') should be present halfway through the reverse transition.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Page Two'), findsOneWidget);

      // Text('Page Two') should be present at the very end of the reverse transition.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Page Two'), findsOneWidget);

      // Text('Page Two') have transitioned out after 300ms.
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Page Two'), findsNothing);
      expect(find.text('Open page'), findsOneWidget);
    });

    testWidgets('reverseTransitionDuration can be customized', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute<dynamic>(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    PageRouteBuilder<void>(
                      settings: settings,
                      pageBuilder: (BuildContext context, Animation<double> input, Animation<double> out) {
                        return const Text('Page Two');
                      },
                      // modified value, default PageRouteBuilder reverse transition duration should be 300ms.
                      reverseTransitionDuration: const Duration(milliseconds: 150),
                    ),
                  );
                },
                child: const Text('Open page'),
              );
            },
          );
        },
      ));

      // Open the new route.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('Open page'), findsNothing);
      expect(find.text('Page Two'), findsOneWidget);

      // Pop the new route.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      expect(find.text('Page Two'), findsOneWidget);

      // Text('Page Two') should be present halfway through the reverse transition.
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.text('Page Two'), findsOneWidget);

      // Text('Page Two') should be present at the very end of the reverse transition.
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.text('Page Two'), findsOneWidget);

      // Text('Page Two') have transitioned out after 500ms.
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Page Two'), findsNothing);
      expect(find.text('Open page'), findsOneWidget);
    });
  });

  group('TransitionRoute', () {
    testWidgets('secondary animation is kDismissed when next route finishes pop', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Text('home'),
        ),
      );

      // Push page one, its secondary animation is kAlwaysDismissedAnimation.
      late ProxyAnimation secondaryAnimationProxyPageOne;
      late ProxyAnimation animationPageOne;
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            secondaryAnimationProxyPageOne = secondaryAnimation as ProxyAnimation;
            animationPageOne = animation as ProxyAnimation;
            return const Text('Page One');
          },
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final ProxyAnimation secondaryAnimationPageOne = secondaryAnimationProxyPageOne.parent! as ProxyAnimation;
      expect(animationPageOne.value, 1.0);
      expect(secondaryAnimationPageOne.parent, kAlwaysDismissedAnimation);

      // Push page two, the secondary animation of page one is the primary
      // animation of page two.
      late ProxyAnimation secondaryAnimationProxyPageTwo;
      late ProxyAnimation animationPageTwo;
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            secondaryAnimationProxyPageTwo = secondaryAnimation as ProxyAnimation;
            animationPageTwo = animation as ProxyAnimation;
            return const Text('Page Two');
          },
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final ProxyAnimation secondaryAnimationPageTwo = secondaryAnimationProxyPageTwo.parent! as ProxyAnimation;
      expect(animationPageTwo.value, 1.0);
      expect(secondaryAnimationPageTwo.parent, kAlwaysDismissedAnimation);
      expect(secondaryAnimationPageOne.parent, animationPageTwo.parent);

      // Pop page two, the secondary animation of page one becomes
      // kAlwaysDismissedAnimation.
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(secondaryAnimationPageOne.parent, animationPageTwo.parent);
      await tester.pumpAndSettle();
      expect(animationPageTwo.value, 0.0);
      expect(secondaryAnimationPageOne.parent, kAlwaysDismissedAnimation);
    });

    testWidgets('secondary animation is kDismissed when next route is removed', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Text('home'),
        ),
      );

      // Push page one, its secondary animation is kAlwaysDismissedAnimation.
      late ProxyAnimation secondaryAnimationProxyPageOne;
      late ProxyAnimation animationPageOne;
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            secondaryAnimationProxyPageOne = secondaryAnimation as ProxyAnimation;
            animationPageOne = animation as ProxyAnimation;
            return const Text('Page One');
          },
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final ProxyAnimation secondaryAnimationPageOne = secondaryAnimationProxyPageOne.parent! as ProxyAnimation;
      expect(animationPageOne.value, 1.0);
      expect(secondaryAnimationPageOne.parent, kAlwaysDismissedAnimation);

      // Push page two, the secondary animation of page one is the primary
      // animation of page two.
      late ProxyAnimation secondaryAnimationProxyPageTwo;
      late ProxyAnimation animationPageTwo;
      Route<void> secondRoute;
      navigator.currentState!.push(
        secondRoute = PageRouteBuilder<void>(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            secondaryAnimationProxyPageTwo = secondaryAnimation as ProxyAnimation;
            animationPageTwo = animation as ProxyAnimation;
            return const Text('Page Two');
          },
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final ProxyAnimation secondaryAnimationPageTwo = secondaryAnimationProxyPageTwo.parent! as ProxyAnimation;
      expect(animationPageTwo.value, 1.0);
      expect(secondaryAnimationPageTwo.parent, kAlwaysDismissedAnimation);
      expect(secondaryAnimationPageOne.parent, animationPageTwo.parent);

      // Remove the second route, the secondary animation of page one is
      // kAlwaysDismissedAnimation again.
      navigator.currentState!.removeRoute(secondRoute);
      await tester.pump();
      expect(secondaryAnimationPageOne.parent, kAlwaysDismissedAnimation);
    });

    testWidgets('secondary animation is kDismissed after train hopping finishes and pop', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Text('home'),
        ),
      );

      // Push page one, its secondary animation is kAlwaysDismissedAnimation.
      late ProxyAnimation secondaryAnimationProxyPageOne;
      late ProxyAnimation animationPageOne;
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            secondaryAnimationProxyPageOne = secondaryAnimation as ProxyAnimation;
            animationPageOne = animation as ProxyAnimation;
            return const Text('Page One');
          },
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final ProxyAnimation secondaryAnimationPageOne = secondaryAnimationProxyPageOne.parent! as ProxyAnimation;
      expect(animationPageOne.value, 1.0);
      expect(secondaryAnimationPageOne.parent, kAlwaysDismissedAnimation);

      // Push page two, the secondary animation of page one is the primary
      // animation of page two.
      late ProxyAnimation animationPageTwo;
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            animationPageTwo = animation as ProxyAnimation;
            return const Text('Page Two');
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(secondaryAnimationPageOne.parent, animationPageTwo.parent);

      // Replace with a different route while push is ongoing to trigger
      // TrainHopping.
      late ProxyAnimation animationPageThree;
      navigator.currentState!.pushReplacement(
        TestPageRouteBuilder(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            animationPageThree = animation as ProxyAnimation;
            return const Text('Page Three');
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(secondaryAnimationPageOne.parent, isA<TrainHoppingAnimation>());
      final TrainHoppingAnimation trainHopper = secondaryAnimationPageOne.parent! as TrainHoppingAnimation;
      expect(trainHopper.currentTrain, animationPageTwo.parent);
      await tester.pump(const Duration(milliseconds: 100));
      expect(secondaryAnimationPageOne.parent, isNot(isA<TrainHoppingAnimation>()));
      expect(secondaryAnimationPageOne.parent, animationPageThree.parent);
      expect(trainHopper.currentTrain, isNull); // Has been disposed.
      await tester.pumpAndSettle();
      expect(secondaryAnimationPageOne.parent, animationPageThree.parent);

      // Pop page three.
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(secondaryAnimationPageOne.parent, kAlwaysDismissedAnimation);
    });

    testWidgets('secondary animation is kDismissed when train hopping is interrupted', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Text('home'),
        ),
      );

      // Push page one, its secondary animation is kAlwaysDismissedAnimation.
      late ProxyAnimation secondaryAnimationProxyPageOne;
      late ProxyAnimation animationPageOne;
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            secondaryAnimationProxyPageOne = secondaryAnimation as ProxyAnimation;
            animationPageOne = animation as ProxyAnimation;
            return const Text('Page One');
          },
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final ProxyAnimation secondaryAnimationPageOne = secondaryAnimationProxyPageOne.parent! as ProxyAnimation;
      expect(animationPageOne.value, 1.0);
      expect(secondaryAnimationPageOne.parent, kAlwaysDismissedAnimation);

      // Push page two, the secondary animation of page one is the primary
      // animation of page two.
      late ProxyAnimation animationPageTwo;
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            animationPageTwo = animation as ProxyAnimation;
            return const Text('Page Two');
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(secondaryAnimationPageOne.parent, animationPageTwo.parent);

      // Replace with a different route while push is ongoing to trigger
      // TrainHopping.
      navigator.currentState!.pushReplacement(
        TestPageRouteBuilder(
          pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
            return const Text('Page Three');
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(secondaryAnimationPageOne.parent, isA<TrainHoppingAnimation>());
      final TrainHoppingAnimation trainHopper = secondaryAnimationPageOne.parent! as TrainHoppingAnimation;
      expect(trainHopper.currentTrain, animationPageTwo.parent);

      // Pop page three while replacement push is ongoing.
      navigator.currentState!.pop();
      await tester.pump();
      expect(secondaryAnimationPageOne.parent, isA<TrainHoppingAnimation>());
      final TrainHoppingAnimation trainHopper2 = secondaryAnimationPageOne.parent! as TrainHoppingAnimation;
      expect(trainHopper2.currentTrain, animationPageTwo.parent);
      expect(trainHopper.currentTrain, isNull); // Has been disposed.
      await tester.pumpAndSettle();
      expect(secondaryAnimationPageOne.parent, kAlwaysDismissedAnimation);
      expect(trainHopper2.currentTrain, isNull); // Has been disposed.
    });

    testWidgets('secondary animation is triggered when pop initial route', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      late Animation<double> secondaryAnimationOfRouteOne;
      late Animation<double> primaryAnimationOfRouteTwo;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          onGenerateRoute: (RouteSettings settings) {
            return PageRouteBuilder<void>(
              settings: settings,
              pageBuilder: (_, Animation<double> animation, Animation<double> secondaryAnimation) {
                if (settings.name == '/')
                  secondaryAnimationOfRouteOne = secondaryAnimation;
                else
                  primaryAnimationOfRouteTwo = animation;
                return const Text('Page');
              },
            );
          },
          initialRoute: '/a',
        ),
      );
      // The secondary animation of the bottom route should be chained with the
      // primary animation of top most route.
      expect(secondaryAnimationOfRouteOne.value, 1.0);
      expect(secondaryAnimationOfRouteOne.value, primaryAnimationOfRouteTwo.value);
      // Pops the top most route and verifies two routes are still chained.
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(secondaryAnimationOfRouteOne.value, 0.9);
      expect(secondaryAnimationOfRouteOne.value, primaryAnimationOfRouteTwo.value);
      await tester.pumpAndSettle();
      expect(secondaryAnimationOfRouteOne.value, 0.0);
      expect(secondaryAnimationOfRouteOne.value, primaryAnimationOfRouteTwo.value);
    });

    testWidgets('showGeneralDialog handles transparent barrier color', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () {
                showGeneralDialog<void>(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: 'barrier_label',
                  barrierColor: const Color(0x00000000),
                  transitionDuration: Duration.zero,
                  pageBuilder: (BuildContext innerContext, _, __) {
                    return const SizedBox();
                  },
                );
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ));

      // Open the dialog.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(ModalBarrier), findsNWidgets(2));

      // Close the dialog.
      await tester.tapAt(Offset.zero);
      await tester.pump();
      expect(find.byType(ModalBarrier), findsNWidgets(1));
    });

    testWidgets('showGeneralDialog adds non-dismissible barrier when barrierDismissible is false', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () {
                showGeneralDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  transitionDuration: Duration.zero,
                  pageBuilder: (BuildContext innerContext, _, __) {
                    return const SizedBox();
                  },
                );
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ));

      // Open the dialog.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(ModalBarrier), findsNWidgets(2));
      final ModalBarrier barrier = find.byType(ModalBarrier).evaluate().last.widget as ModalBarrier;
      expect(barrier.dismissible, isFalse);

      // Close the dialog.
      final StatefulElement navigatorElement = find.byType(Navigator).evaluate().last as StatefulElement;
      final NavigatorState navigatorState = navigatorElement.state as NavigatorState;
      navigatorState.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ModalBarrier), findsNWidgets(1));
    });

    testWidgets('showGeneralDialog uses null as a barrierLabel by default', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () {
                showGeneralDialog<void>(
                  context: context,
                  transitionDuration: Duration.zero,
                  pageBuilder: (BuildContext innerContext, _, __) {
                    return const SizedBox();
                  },
                );
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ));

      // Open the dialog.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(ModalBarrier), findsNWidgets(2));
      final ModalBarrier barrier = find.byType(ModalBarrier).evaluate().last.widget as ModalBarrier;
      expect(barrier.semanticsLabel, same(null));

      // Close the dialog.
      final StatefulElement navigatorElement = find.byType(Navigator).evaluate().last as StatefulElement;
      final NavigatorState navigatorState = navigatorElement.state as NavigatorState;
      navigatorState.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ModalBarrier), findsNWidgets(1));
    });

    testWidgets('showGeneralDialog uses root navigator by default', (WidgetTester tester) async {
      final DialogObserver rootObserver = DialogObserver();
      final DialogObserver nestedObserver = DialogObserver();

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: <NavigatorObserver>[rootObserver],
        home: Navigator(
          observers: <NavigatorObserver>[nestedObserver],
          onGenerateRoute: (RouteSettings settings) {
            return MaterialPageRoute<dynamic>(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    showGeneralDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      transitionDuration: Duration.zero,
                      pageBuilder: (BuildContext innerContext, _, __) {
                        return const SizedBox();
                      },
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            );
          },
        ),
      ));

      // Open the dialog.
      await tester.tap(find.byType(ElevatedButton));

      expect(rootObserver.dialogCount, 1);
      expect(nestedObserver.dialogCount, 0);
    });

    testWidgets('showGeneralDialog uses nested navigator if useRootNavigator is false', (WidgetTester tester) async {
      final DialogObserver rootObserver = DialogObserver();
      final DialogObserver nestedObserver = DialogObserver();

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: <NavigatorObserver>[rootObserver],
        home: Navigator(
          observers: <NavigatorObserver>[nestedObserver],
          onGenerateRoute: (RouteSettings settings) {
            return MaterialPageRoute<dynamic>(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    showGeneralDialog<void>(
                      useRootNavigator: false,
                      context: context,
                      barrierDismissible: false,
                      transitionDuration: Duration.zero,
                      pageBuilder: (BuildContext innerContext, _, __) {
                        return const SizedBox();
                      },
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            );
          },
        ),
      ));

      // Open the dialog.
      await tester.tap(find.byType(ElevatedButton));

      expect(rootObserver.dialogCount, 0);
      expect(nestedObserver.dialogCount, 1);
    });

    testWidgets('showGeneralDialog default argument values', (WidgetTester tester) async {
      final DialogObserver rootObserver = DialogObserver();

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: <NavigatorObserver>[rootObserver],
        home: Navigator(
          onGenerateRoute: (RouteSettings settings) {
            return MaterialPageRoute<dynamic>(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    showGeneralDialog<void>(
                      context: context,
                      pageBuilder: (BuildContext innerContext, _, __) {
                        return const SizedBox();
                      },
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            );
          },
        ),
      ));

      // Open the dialog.
      await tester.tap(find.byType(ElevatedButton));
      expect(rootObserver.dialogRoutes.length, equals(1));
      final ModalRoute<dynamic> route = rootObserver.dialogRoutes.last;
      expect(route.barrierDismissible, isNotNull);
      expect(route.barrierColor, isNotNull);
      expect(route.transitionDuration, isNotNull);
    });

    testWidgets('reverseTransitionDuration defaults to transitionDuration', (WidgetTester tester) async {
      final GlobalKey containerKey = GlobalKey();

      // Default MaterialPageRoute transition duration should be 300ms.
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute<dynamic>(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext innerContext) {
                        return Container(
                          key: containerKey,
                          color: Colors.green,
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open page'),
              );
            },
          );
        },
      ));

      // Open the new route.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('Open page'), findsNothing);
      expect(find.byKey(containerKey), findsOneWidget);

      // Pop the new route.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      expect(find.byKey(containerKey), findsOneWidget);

      // Container should be present halfway through the transition.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(containerKey), findsOneWidget);

      // Container should be present at the very end of the transition.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(containerKey), findsOneWidget);

      // Container have transitioned out after 300ms.
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(containerKey), findsNothing);
    });

    testWidgets('reverseTransitionDuration can be customized', (WidgetTester tester) async {
      final GlobalKey containerKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute<dynamic>(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    ModifiedReverseTransitionDurationRoute<void>(
                      builder: (BuildContext innerContext) {
                        return Container(
                          key: containerKey,
                          color: Colors.green,
                        );
                      },
                      // modified value, default MaterialPageRoute transition duration should be 300ms.
                      reverseTransitionDuration: const Duration(milliseconds: 150),
                    ),
                  );
                },
                child: const Text('Open page'),
              );
            },
          );
        },
      ));

      // Open the new route.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('Open page'), findsNothing);
      expect(find.byKey(containerKey), findsOneWidget);

      // Pop the new route.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      expect(find.byKey(containerKey), findsOneWidget);

      // Container should be present halfway through the transition.
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.byKey(containerKey), findsOneWidget);

      // Container should be present at the very end of the transition.
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.byKey(containerKey), findsOneWidget);

      // Container have transitioned out after 150ms.
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(containerKey), findsNothing);
    });

    testWidgets('custom reverseTransitionDuration does not result in interrupted animations', (WidgetTester tester) async {
      final GlobalKey containerKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: <TargetPlatform, PageTransitionsBuilder>{
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(), // use a fade transition
            },
          ),
        ),
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute<dynamic>(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    ModifiedReverseTransitionDurationRoute<void>(
                      builder: (BuildContext innerContext) {
                        return Container(
                          key: containerKey,
                          color: Colors.green,
                        );
                      },
                      // modified value, default MaterialPageRoute transition duration should be 300ms.
                      reverseTransitionDuration: const Duration(milliseconds: 150),
                    ),
                  );
                },
                child: const Text('Open page'),
              );
            },
          );
        },
      ));

      // Open the new route.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // jump partway through the forward transition
      expect(find.byKey(containerKey), findsOneWidget);

      // Gets the opacity of the fade transition while animating forwards.
      final double topFadeTransitionOpacity = _getOpacity(containerKey, tester);

      // Pop the new route mid-transition.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();

      // Transition should not jump. In other words, the fade transition
      // opacity before and after animation changes directions should remain
      // the same.
      expect(_getOpacity(containerKey, tester), topFadeTransitionOpacity);

      // Reverse transition duration should be:
      // Forward transition elapsed time: 200ms / 300ms = 2 / 3
      // Reverse transition remaining time: 150ms * 2 / 3 = 100ms

      // Container should be present at the very end of the transition.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(containerKey), findsOneWidget);

      // Container have transitioned out after 100ms.
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(containerKey), findsNothing);
    });
  });

  group('ModalRoute', () {
    testWidgets('default barrierCurve', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: Builder(
            builder: (BuildContext context) {
              return Center(
                child: ElevatedButton(
                  child: const Text('X'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      _TestDialogRouteWithCustomBarrierCurve<void>(
                        child: const Text('Hello World'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ));

      final CurveTween defaultBarrierTween = CurveTween(curve: Curves.ease);
      int _getExpectedBarrierTweenAlphaValue(double t) {
        return Color.getAlphaFromOpacity(defaultBarrierTween.transform(t));
      }

      await tester.tap(find.text('X'));
      await tester.pump();
      final Finder animatedModalBarrier = find.byType(AnimatedModalBarrier);
      expect(animatedModalBarrier, findsOneWidget);

      Animation<Color?> modalBarrierAnimation;
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(modalBarrierAnimation.value, Colors.transparent);

      await tester.pump(const Duration(milliseconds: 25));
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(
        modalBarrierAnimation.value!.alpha,
        closeTo(_getExpectedBarrierTweenAlphaValue(0.25), 1),
      );

      await tester.pump(const Duration(milliseconds: 25));
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(
        modalBarrierAnimation.value!.alpha,
        closeTo(_getExpectedBarrierTweenAlphaValue(0.50), 1),
      );

      await tester.pump(const Duration(milliseconds: 25));
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(
        modalBarrierAnimation.value!.alpha,
        closeTo(_getExpectedBarrierTweenAlphaValue(0.75), 1),
      );

      await tester.pumpAndSettle();
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(modalBarrierAnimation.value, Colors.black);
    });

    testWidgets('custom barrierCurve', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: Builder(
            builder: (BuildContext context) {
              return Center(
                child: ElevatedButton(
                  child: const Text('X'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      _TestDialogRouteWithCustomBarrierCurve<void>(
                        child: const Text('Hello World'),
                        barrierCurve: Curves.linear,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ));

      final CurveTween customBarrierTween = CurveTween(curve: Curves.linear);
      int _getExpectedBarrierTweenAlphaValue(double t) {
        return Color.getAlphaFromOpacity(customBarrierTween.transform(t));
      }

      await tester.tap(find.text('X'));
      await tester.pump();
      final Finder animatedModalBarrier = find.byType(AnimatedModalBarrier);
      expect(animatedModalBarrier, findsOneWidget);

      Animation<Color?> modalBarrierAnimation;
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(modalBarrierAnimation.value, Colors.transparent);

      await tester.pump(const Duration(milliseconds: 25));
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(
        modalBarrierAnimation.value!.alpha,
        closeTo(_getExpectedBarrierTweenAlphaValue(0.25), 1),
      );

      await tester.pump(const Duration(milliseconds: 25));
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(
        modalBarrierAnimation.value!.alpha,
        closeTo(_getExpectedBarrierTweenAlphaValue(0.50), 1),
      );

      await tester.pump(const Duration(milliseconds: 25));
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(
        modalBarrierAnimation.value!.alpha,
        closeTo(_getExpectedBarrierTweenAlphaValue(0.75), 1),
      );

      await tester.pumpAndSettle();
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(modalBarrierAnimation.value, Colors.black);
    });

    testWidgets('white barrierColor', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: Builder(
            builder: (BuildContext context) {
              return Center(
                child: ElevatedButton(
                  child: const Text('X'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      _TestDialogRouteWithCustomBarrierCurve<void>(
                        child: const Text('Hello World'),
                        barrierColor: Colors.white,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ));

      final CurveTween defaultBarrierTween = CurveTween(curve: Curves.ease);
      int _getExpectedBarrierTweenAlphaValue(double t) {
        return Color.getAlphaFromOpacity(defaultBarrierTween.transform(t));
      }

      await tester.tap(find.text('X'));
      await tester.pump();
      final Finder animatedModalBarrier = find.byType(AnimatedModalBarrier);
      expect(animatedModalBarrier, findsOneWidget);

      Animation<Color?> modalBarrierAnimation;
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(modalBarrierAnimation.value, Colors.white.withOpacity(0));

      await tester.pump(const Duration(milliseconds: 25));
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(
        modalBarrierAnimation.value!.alpha,
        closeTo(_getExpectedBarrierTweenAlphaValue(0.25), 1),
      );

      await tester.pump(const Duration(milliseconds: 25));
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(
        modalBarrierAnimation.value!.alpha,
        closeTo(_getExpectedBarrierTweenAlphaValue(0.50), 1),
      );

      await tester.pump(const Duration(milliseconds: 25));
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(
        modalBarrierAnimation.value!.alpha,
        closeTo(_getExpectedBarrierTweenAlphaValue(0.75), 1),
      );

      await tester.pumpAndSettle();
      modalBarrierAnimation = tester.widget<AnimatedModalBarrier>(animatedModalBarrier).color;
      expect(modalBarrierAnimation.value, Colors.white);
    });

    testWidgets('modal route semantics order', (WidgetTester tester) async {
      // Regression test for https://github.com/flutter/flutter/issues/46625.
      final SemanticsTester semantics = SemanticsTester(tester);
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: Builder(
            builder: (BuildContext context) {
              return Center(
                child: ElevatedButton(
                  child: const Text('X'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      _TestDialogRouteWithCustomBarrierCurve<void>(
                        child: const Text('Hello World'),
                        barrierLabel: 'test label',
                        barrierCurve: Curves.linear,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ));

      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();
      expect(find.text('Hello World'), findsOneWidget);

      final TestSemantics expectedSemantics = TestSemantics.root(
        children: <TestSemantics>[
          TestSemantics.rootChild(
            id: 1,
            rect: TestSemantics.fullScreen,
            children: <TestSemantics>[
              TestSemantics(
                id: 6,
                rect: TestSemantics.fullScreen,
                children: <TestSemantics>[
                  TestSemantics(
                    id: 7,
                    rect: TestSemantics.fullScreen,
                    flags: <SemanticsFlag>[SemanticsFlag.scopesRoute],
                    children: <TestSemantics>[
                      TestSemantics(
                        id: 8,
                        label: 'Hello World',
                        rect: TestSemantics.fullScreen,
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ],
              ),
              // Modal barrier is put after modal scope
              TestSemantics(
                id: 5,
                rect: TestSemantics.fullScreen,
                actions: <SemanticsAction>[SemanticsAction.tap, SemanticsAction.dismiss],
                label: 'test label',
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ],
      )
      ;

      expect(semantics, hasSemantics(expectedSemantics));
      semantics.dispose();
    }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS}));

    testWidgets('focus traverse correct when pop multiple page simultaneously', (WidgetTester tester) async {
      // Regression test: https://github.com/flutter/flutter/issues/48903
      final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Text('dummy1'),
      ));
      final Element textOnPageOne = tester.element(find.text('dummy1'));
      final FocusScopeNode focusNodeOnPageOne = FocusScope.of(textOnPageOne);
      expect(focusNodeOnPageOne.hasFocus, isTrue);

      // Pushes one page.
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const Text('dummy2'),
        ),
      );
      await tester.pumpAndSettle();

      final Element textOnPageTwo = tester.element(find.text('dummy2'));
      final FocusScopeNode focusNodeOnPageTwo = FocusScope.of(textOnPageTwo);
      // The focus should be on second page.
      expect(focusNodeOnPageOne.hasFocus, isFalse);
      expect(focusNodeOnPageTwo.hasFocus, isTrue);

      // Pushes another page.
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const Text('dummy3'),
        ),
      );
      await tester.pumpAndSettle();
      final Element textOnPageThree = tester.element(find.text('dummy3'));
      final FocusScopeNode focusNodeOnPageThree = FocusScope.of(textOnPageThree);
      // The focus should be on third page.
      expect(focusNodeOnPageOne.hasFocus, isFalse);
      expect(focusNodeOnPageTwo.hasFocus, isFalse);
      expect(focusNodeOnPageThree.hasFocus, isTrue);

      // Pops two pages simultaneously.
      navigatorKey.currentState!.popUntil((Route<void> route) => route.isFirst);
      await tester.pumpAndSettle();
      // It should refocus page one after pops.
      expect(focusNodeOnPageOne.hasFocus, isTrue);
    });

    testWidgets('focus traversal is correct when popping multiple pages simultaneously - with focused children', (WidgetTester tester) async {
      // Regression test: https://github.com/flutter/flutter/issues/48903
      final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Text('dummy1'),
      ));
      final Element textOnPageOne = tester.element(find.text('dummy1'));
      final FocusScopeNode focusNodeOnPageOne = FocusScope.of(textOnPageOne);
      expect(focusNodeOnPageOne.hasFocus, isTrue);

      // Pushes one page.
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const Material(child: TextField()),
        ),
      );
      await tester.pumpAndSettle();

      final Element textOnPageTwo = tester.element(find.byType(TextField));
      final FocusScopeNode focusNodeOnPageTwo = FocusScope.of(textOnPageTwo);
      // The focus should be on second page.
      expect(focusNodeOnPageOne.hasFocus, isFalse);
      expect(focusNodeOnPageTwo.hasFocus, isTrue);

      // Move the focus to another node.
      focusNodeOnPageTwo.nextFocus();
      await tester.pumpAndSettle();
      expect(focusNodeOnPageTwo.hasFocus, isTrue);
      expect(focusNodeOnPageTwo.hasPrimaryFocus, isFalse);

      // Pushes another page.
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const Text('dummy3'),
        ),
      );
      await tester.pumpAndSettle();
      final Element textOnPageThree = tester.element(find.text('dummy3'));
      final FocusScopeNode focusNodeOnPageThree = FocusScope.of(textOnPageThree);
      // The focus should be on third page.
      expect(focusNodeOnPageOne.hasFocus, isFalse);
      expect(focusNodeOnPageTwo.hasFocus, isFalse);
      expect(focusNodeOnPageThree.hasFocus, isTrue);

      // Pops two pages simultaneously.
      navigatorKey.currentState!.popUntil((Route<void> route) => route.isFirst);
      await tester.pumpAndSettle();
      // It should refocus page one after pops.
      expect(focusNodeOnPageOne.hasFocus, isTrue);
    });

    testWidgets('child with local history can be disposed', (WidgetTester tester) async {
      // Regression test: https://github.com/flutter/flutter/issues/52478
      await tester.pumpWidget(const MaterialApp(
        home: WidgetWithLocalHistory(),
      ));

      final WidgetWithLocalHistoryState state = tester.state(find.byType(WidgetWithLocalHistory));
      state.addLocalHistory();
      // Waits for modal route to update its internal state;
      await tester.pump();
      // Pumps a new widget to dispose WidgetWithLocalHistory. This should cause
      // it to remove the local history entry from modal route during
      // finalizeTree.
      await tester.pumpWidget(const MaterialApp(
        home: Text('dummy'),
      ));
      // Waits for modal route to update its internal state;
      await tester.pump();
      expect(tester.takeException(), null);
    });

    testWidgets('child with no local history can be disposed', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: WidgetWithNoLocalHistory(),
      ));

      final WidgetWithNoLocalHistoryState state = tester.state(find.byType(WidgetWithNoLocalHistory));
      state.addLocalHistory();
      // Waits for modal route to update its internal state;
      await tester.pump();
      // Pumps a new widget to dispose WidgetWithNoLocalHistory. This should cause
      // it to remove the local history entry from modal route during
      // finalizeTree.
      await tester.pumpWidget(const MaterialApp(
        home: Text('dummy'),
      ));
      await tester.pump();
      expect(tester.takeException(), null);
    });
  });

  testWidgets('can be dismissed with escape keyboard shortcut', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Text('dummy1'),
    ));
    final Element textOnPageOne = tester.element(find.text('dummy1'));

    // Show a simple dialog
    showDialog<void>(
      context: textOnPageOne,
      builder: (BuildContext context) => const Text('dialog1'),
    );
    await tester.pumpAndSettle();
    expect(find.text('dialog1'), findsOneWidget);

    // Try to dismiss the dialog with the shortcut key
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('dialog1'), findsNothing);
  });

  testWidgets('can not be dismissed with escape keyboard shortcut if barrier not dismissible', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Text('dummy1'),
    ));
    final Element textOnPageOne = tester.element(find.text('dummy1'));

    // Show a simple dialog
    showDialog<void>(
      context: textOnPageOne,
      barrierDismissible: false,
      builder: (BuildContext context) => const Text('dialog1'),
    );
    await tester.pumpAndSettle();
    expect(find.text('dialog1'), findsOneWidget);

    // Try to dismiss the dialog with the shortcut key
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('dialog1'), findsOneWidget);
  });

  testWidgets('ModalRoute.of works for void routes', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Text('home'),
    ));
    expect(find.text('page2'), findsNothing);

    navigatorKey.currentState!.push<void>(MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return const Text('page2');
      },
    ));

    await tester.pumpAndSettle();
    expect(find.text('page2'), findsOneWidget);

    final ModalRoute<void>? parentRoute = ModalRoute.of<void>(tester.element(find.text('page2')));
    expect(parentRoute, isNotNull);
    expect(parentRoute, isA<MaterialPageRoute<void>>());
  });

  testWidgets('RawDialogRoute is state restorable', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: _RestorableDialogTestWidget(),
      ),
    );

    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    final TestRestorationData restorationData = await tester.getRestorationData();

    await tester.restartAndRestore();

    expect(find.byType(AlertDialog), findsOneWidget);

    // Tap on the barrier.
    await tester.tapAt(const Offset(10.0, 10.0));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);

    await tester.restoreFrom(restorationData);
    expect(find.byType(AlertDialog), findsOneWidget);
  }, skip: isBrowser); // https://github.com/flutter/flutter/issues/33615
}

double _getOpacity(GlobalKey key, WidgetTester tester) {
  final Finder finder = find.ancestor(
    of: find.byKey(key),
    matching: find.byType(FadeTransition),
  );
  return tester.widgetList(finder).fold<double>(1.0, (double a, Widget widget) {
    final FadeTransition transition = widget as FadeTransition;
    return a * transition.opacity.value;
  });
}

class ModifiedReverseTransitionDurationRoute<T> extends MaterialPageRoute<T> {
  ModifiedReverseTransitionDurationRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    required this.reverseTransitionDuration,
    bool fullscreenDialog = false,
  }) : super(
         builder: builder,
         settings: settings,
         fullscreenDialog: fullscreenDialog,
       );

  @override
  final Duration reverseTransitionDuration;
}

class MockPageRoute extends Fake implements PageRoute<dynamic> { }

class MockRoute extends Fake implements Route<dynamic> { }

class MockRouteAware extends Fake implements RouteAware {
  int didPushCount = 0;
  int didPushNextCount = 0;
  int didPopCount = 0;
  int didPopNextCount = 0;

  @override
  void didPush() {
    didPushCount += 1;
  }

  @override
  void didPushNext() {
    didPushNextCount += 1;
  }

  @override
  void didPop() {
    didPopCount += 1;
  }

  @override
  void didPopNext() {
    didPopNextCount += 1;
  }
}

class TestPageRouteBuilder extends PageRouteBuilder<void> {
  TestPageRouteBuilder({required RoutePageBuilder pageBuilder}) : super(pageBuilder: pageBuilder);

  @override
  Animation<double> createAnimation() {
    return CurvedAnimation(parent: super.createAnimation(), curve: Curves.easeOutExpo);
  }
}

class DialogObserver extends NavigatorObserver {
  final List<ModalRoute<dynamic>> dialogRoutes = <ModalRoute<dynamic>>[];
  int dialogCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is RawDialogRoute) {
      dialogRoutes.add(route);
      dialogCount++;
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is RawDialogRoute) {
      dialogRoutes.removeLast();
      dialogCount--;
    }
    super.didPop(route, previousRoute);
  }
}

class _TestDialogRouteWithCustomBarrierCurve<T> extends PopupRoute<T> {
  _TestDialogRouteWithCustomBarrierCurve({
    required Widget child,
    this.barrierLabel,
    this.barrierColor = Colors.black,
    Curve? barrierCurve,
  }) : _barrierCurve = barrierCurve,
       _child = child;

  final Widget _child;

  @override
  bool get barrierDismissible => true;

  @override
  final String? barrierLabel;

  @override
  final Color? barrierColor;

  @override
  Curve get barrierCurve {
    if (_barrierCurve == null) {
      return super.barrierCurve;
    }
    return _barrierCurve!;
  }
  final Curve? _barrierCurve;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 100); // easier value to test against

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _child,
    );
  }
}

class WidgetWithLocalHistory extends StatefulWidget {
  const WidgetWithLocalHistory({Key? key}) : super(key: key);

  @override
  WidgetWithLocalHistoryState createState() => WidgetWithLocalHistoryState();
}

class WidgetWithLocalHistoryState extends State<WidgetWithLocalHistory> {
  late LocalHistoryEntry _localHistory;

  void addLocalHistory() {
    final ModalRoute<dynamic> route = ModalRoute.of(context)!;
    _localHistory = LocalHistoryEntry();
    route.addLocalHistoryEntry(_localHistory);
  }

  @override
  void dispose() {
    super.dispose();
    _localHistory.remove();
  }

  @override
  Widget build(BuildContext context) {
    return const Text('dummy');
  }
}

class WidgetWithNoLocalHistory extends StatefulWidget {
  const WidgetWithNoLocalHistory({Key? key}) : super(key: key);

  @override
  WidgetWithNoLocalHistoryState createState() => WidgetWithNoLocalHistoryState();
}

class WidgetWithNoLocalHistoryState extends State<WidgetWithNoLocalHistory> {
  late LocalHistoryEntry _localHistory;

  void addLocalHistory() {
    _localHistory = LocalHistoryEntry();
    // Not calling `route.addLocalHistoryEntry` here.
  }

  @override
  void dispose() {
    super.dispose();
    _localHistory.remove();
  }

  @override
  Widget build(BuildContext context) {
    return const Text('dummy');
  }
}

class TransitionDetector extends DefaultTransitionDelegate<void> {
  bool hasTransition = false;
  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord> locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>> pageRouteToPagelessRoutes,
  }) {
    hasTransition = true;
    return super.resolve(
      newPageRouteHistory: newPageRouteHistory,
      locationToExitingPageRoute: locationToExitingPageRoute,
      pageRouteToPagelessRoutes: pageRouteToPagelessRoutes,
    );
  }
}

Widget buildNavigator({
  required List<Page<dynamic>> pages,
  required PopPageCallback onPopPage,
  GlobalKey<NavigatorState>? key,
  TransitionDelegate<dynamic>? transitionDelegate,
}) {
  return MediaQuery(
    data: MediaQueryData.fromWindow(WidgetsBinding.instance!.window),
    child: Localizations(
      locale: const Locale('en', 'US'),
      delegates: const <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Navigator(
          key: key,
          pages: pages,
          onPopPage: onPopPage,
          transitionDelegate: transitionDelegate ?? const DefaultTransitionDelegate<dynamic>(),
        ),
      ),
    ),
  );
}

class _RestorableDialogTestWidget extends StatelessWidget {
  static Route<Object?> _dialogBuilder(BuildContext context, Object? arguments) {
    return RawDialogRoute<void>(
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return const AlertDialog(title: Text('Alert!'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: OutlinedButton(
          onPressed: () {
            Navigator.of(context).restorablePush(_dialogBuilder);
          },
          child: const Text('X'),
        ),
      ),
    );
  }
}
