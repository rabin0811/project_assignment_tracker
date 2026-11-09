// A smoke test for the Assignment Tracker app.
//
// The app reads from SQLite on start-up, so the test swaps the sqflite
// factory for the sqflite_common_ffi in-memory/native factory. The sqlite
// calls run on the real event loop, so the test uses tester.runAsync to
// prime the connection and let query results be delivered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:assignment_tracker/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Dashboard renders summary cards and empty state',
      (WidgetTester tester) async {
    // Open the in-memory database with real async so the connection is
    // cached by the time the widget builds.
    await tester.runAsync(() => AssignmentDatabase.instance.getAll());

    await tester.pumpWidget(const AssignmentTrackerApp());
    await tester.pump();

    // Let the real event loop deliver the database query result.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();

    // App bar and intro line are visible.
    expect(find.text('Assignment Tracker'), findsWidgets);
    expect(find.text('Your work, organised.'), findsOneWidget);

    // Summary cards are shown.
    expect(find.text('Outstanding balance'), findsOneWidget);
    expect(find.text('Total expected'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);

    // Filter chips are rendered (first chip visible on screen).
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.text('All'), findsOneWidget);

    // With an empty database, the empty state is displayed.
    expect(find.text('No assignments here'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
