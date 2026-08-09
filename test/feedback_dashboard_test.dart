import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/admin_feedback.dart';
import 'package:homevault/models/beta_feedback.dart';
import 'package:homevault/screens/feedback/feedback_dashboard_screen.dart';
import 'package:homevault/services/feedback_admin_service.dart';

class _FakeFeedbackRepository implements FeedbackAdminRepository {
  _FakeFeedbackRepository({required this.admin, required this.items});

  final bool admin;
  final List<AdminFeedbackItem> items;
  final List<FeedbackWorkflowStatus> statusUpdates = [];

  @override
  Future<bool> isAdmin(String uid) async => admin;

  @override
  Stream<List<AdminFeedbackItem>> watchFeedback() => Stream.value(items);

  @override
  Future<void> updateFeedback({
    required AdminFeedbackItem item,
    required String adminUid,
    FeedbackWorkflowStatus? status,
    FeedbackPriority? priority,
    String? adminNote,
  }) async {
    if (status != null) statusUpdates.add(status);
  }
}

AdminFeedbackItem _feedback({
  String id = 'feedback-1',
  FeedbackWorkflowStatus status = FeedbackWorkflowStatus.newFeedback,
}) {
  return AdminFeedbackItem(
    id: id,
    documentPath: 'feedback/$id',
    uid: 'user-1',
    userEmail: 'user@example.com',
    category: FeedbackCategory.bug,
    message: 'The warranty screen does not refresh correctly.',
    createdAt: DateTime(2026, 8, 9, 10),
    appVersion: '1.12.2',
    buildNumber: '17',
    deviceModel: 'Pixel Test',
    status: status,
  );
}

void main() {
  testWidgets('admin sees feedback from the central dashboard', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeFeedbackRepository(
      admin: true,
      items: [_feedback()],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackDashboardScreen(
          adminUid: 'admin-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Feedback dashboard'), findsOneWidget);
    expect(
      find.text('The warranty screen does not refresh correctly.'),
      findsOneWidget,
    );
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('1 feedback item'), findsOneWidget);
  });

  testWidgets('empty dashboard has a clear empty state', (tester) async {
    final repository = _FakeFeedbackRepository(admin: true, items: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackDashboardScreen(
          adminUid: 'admin-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No feedback yet'), findsOneWidget);
    expect(
      find.text('New beta feedback will appear here automatically.'),
      findsOneWidget,
    );
  });

  testWidgets('non-admin cannot open feedback data', (tester) async {
    final repository = _FakeFeedbackRepository(
      admin: false,
      items: [_feedback()],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackDashboardScreen(
          adminUid: 'user-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This dashboard is available only to HomeVault administrators.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('The warranty screen does not refresh correctly.'),
      findsNothing,
    );
  });
}
