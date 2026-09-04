import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/accessibility/homevault_accessibility.dart';
import 'package:homevault/models/admin_feedback.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/beta_feedback.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/screens/documents/document_details_screen.dart';
import 'package:homevault/screens/feedback/feedback_dashboard_screen.dart';
import 'package:homevault/screens/feedback/feedback_detail_screen.dart';
import 'package:homevault/screens/search/global_search_screen.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/feedback_admin_service.dart';
import 'package:homevault/state/app_scope.dart';
import 'package:homevault/state/appliance_store.dart';
import 'package:homevault/widgets/document_attachment_field.dart';
import 'package:homevault/widgets/service_record_tile.dart';
import 'package:homevault/widgets/stored_document_tile.dart';

StoredDocument _document({
  String title = 'Kitchen invoice',
  String fileName = 'private-storage-name.pdf',
}) {
  return StoredDocument(
    id: 'document-1',
    type: DocumentType.invoice,
    title: title,
    fileName: fileName,
    localPath: '/private/internal/path/$fileName',
    sizeBytes: 2048,
    attachedAt: DateTime(2026, 8, 20),
  );
}

Future<ApplianceStore> _storeWith(Appliance appliance) async {
  final store = ApplianceStore(
    repository: MemoryApplianceRepository(initialAppliances: [appliance]),
  );
  await store.initialize();
  return store;
}

SemanticsNode _popupMenuControlSemantics(
  WidgetTester tester,
  Finder popupMenu,
) {
  final semanticTooltip = find.descendant(
    of: popupMenu,
    matching: find.byType(RawTooltip),
  );
  expect(semanticTooltip, findsOneWidget);
  return tester.getSemantics(semanticTooltip);
}

void main() {
  test('contextual action labels stay concise when context is unavailable', () {
    expect(
      HomeVaultAccessibility.contextualAction('Delete', 'Kitchen invoice'),
      'Delete for Kitchen invoice',
    );
    expect(HomeVaultAccessibility.contextualAction('Delete', '  '), 'Delete');
  });

  testWidgets('headings and status announcements expose semantic behavior', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                HomeVaultSectionHeading(
                  child: Text('Backup history', key: Key('phase3Heading')),
                ),
                HomeVaultStatusAnnouncement(
                  key: Key('phase3Status'),
                  message: 'Restoring cloud backup',
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(const Key('phase3Heading'))),
        isSemantics(label: 'Backup history', isHeader: true),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('phase3Status'))),
        isSemantics(label: 'Restoring cloud backup', isLiveRegion: true),
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets(
    'document rows hide filenames and expose contextual transient actions',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        final document = _document();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoredDocumentTile(
                document: document,
                title: document.displayTitle,
                subtitle: 'Invoice for Kitchen refrigerator',
                onOpen: () {},
                onDetails: () {},
                onSaveCopy: () {},
                onEdit: () {},
                onDelete: () {},
              ),
            ),
          ),
        );

        final filenameSemantics = tester
            .getSemantics(find.textContaining(document.fileName))
            .getSemanticsData()
            .label;
        expect(filenameSemantics, isNot(contains(document.fileName)));
        expect(filenameSemantics, contains('On device'));

        final documentContext =
            '${document.displayTitle}, Invoice for Kitchen refrigerator, '
            'added 20 August 2026';
        final actionLabel = 'Document actions for $documentContext';
        final actions = find.byTooltip(actionLabel);
        expect(
          tester.getSemantics(actions),
          isSemantics(tooltip: actionLabel, isButton: true, hasTapAction: true),
        );

        await tester.tap(actions);
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.text('Delete')),
          isSemantics(
            label: 'Delete $documentContext',
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(find.text('Edit metadata')),
          isSemantics(
            label: 'Edit metadata for $documentContext',
            isButton: true,
            hasTapAction: true,
          ),
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets('duplicate document titles have distinct safe action contexts', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      const firstInternalId = 'internal-document-alpha';
      const secondInternalId = 'internal-document-beta';
      const firstFileName = 'private-invoice-alpha.pdf';
      const secondFileName = 'private-invoice-beta.pdf';
      const firstLocalPath = '/private/internal/path/$firstFileName';
      const secondCloudPath =
          'users/internal-user/documents/$secondInternalId/$secondFileName';
      final documents = [
        StoredDocument(
          id: firstInternalId,
          type: DocumentType.invoice,
          title: 'Invoice',
          fileName: firstFileName,
          localPath: firstLocalPath,
          sizeBytes: 2048,
          attachedAt: DateTime(2026, 8, 12),
        ),
        StoredDocument(
          id: secondInternalId,
          type: DocumentType.invoice,
          title: 'Invoice',
          fileName: secondFileName,
          localPath: '',
          cloudStoragePath: secondCloudPath,
          sizeBytes: 4096,
          attachedAt: DateTime(2026, 8, 20),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StoredDocumentTile(
                  document: documents[0],
                  title: 'Invoice',
                  subtitle: 'Invoice for Kitchen refrigerator',
                  onOpen: () {},
                  onDetails: () {},
                ),
                StoredDocumentTile(
                  document: documents[1],
                  title: 'Invoice',
                  subtitle: 'Invoice for Bedroom air conditioner',
                  onOpen: () {},
                  onDetails: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final menus = find.byType(PopupMenuButton<String>);
      expect(menus, findsNWidgets(2));
      final menuSemantics = [
        for (var index = 0; index < 2; index++)
          _popupMenuControlSemantics(tester, menus.at(index)),
      ];
      final actionNames = [
        for (final node in menuSemantics) node.getSemanticsData().tooltip,
      ];

      expect(actionNames.toSet(), hasLength(2));
      expect(
        actionNames[0],
        contains('Invoice for Kitchen refrigerator, added 12 August 2026'),
      );
      expect(
        actionNames[1],
        contains('Invoice for Bedroom air conditioner, added 20 August 2026'),
      );
      for (final node in menuSemantics) {
        expect(node, isSemantics(isButton: true, hasTapAction: true));
      }

      final exposedRowDetails = [
        tester
            .getSemantics(find.textContaining(firstFileName))
            .getSemanticsData()
            .label,
        tester
            .getSemantics(find.textContaining(secondFileName))
            .getSemanticsData()
            .label,
        ...actionNames,
      ].join(' ');
      for (final privateValue in [
        firstInternalId,
        secondInternalId,
        firstFileName,
        secondFileName,
        firstLocalPath,
        secondCloudPath,
      ]) {
        expect(exposedRowDetails, isNot(contains(privateValue)));
      }
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('attachment fields hide filenames and contextualize actions', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      final document = _document(fileName: 'account-42-private-receipt.pdf');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentAttachmentField(
              title: 'Warranty card',
              description: 'Attach the warranty card.',
              icon: Icons.verified_outlined,
              document: document,
              isLoading: false,
              onPick: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      final attachmentSemantics = tester
          .getSemantics(find.text(document.fileName))
          .getSemanticsData()
          .label;
      expect(attachmentSemantics, contains('Warranty card'));
      expect(attachmentSemantics, contains('Attachment selected'));
      expect(attachmentSemantics, isNot(contains(document.fileName)));

      for (final actionLabel in [
        'Replace Warranty card file',
        'Remove Warranty card file',
      ]) {
        final action = find.byTooltip(actionLabel);
        expect(action, findsOneWidget);
        expect(
          tester.getSemantics(action),
          isSemantics(tooltip: actionLabel, isButton: true, hasTapAction: true),
        );
      }
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('repeated service records have distinct safe action contexts', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      var firstEditCount = 0;
      var secondDeleteCount = 0;
      const firstInternalId = 'internal-service-record-alpha';
      const secondInternalId = 'internal-service-record-beta';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ServiceRecordTile(
                  applianceName: 'Kitchen refrigerator',
                  now: DateTime(2026, 8, 25),
                  record: ServiceRecord(
                    id: firstInternalId,
                    serviceDate: DateTime(2026, 8, 12),
                    createdAt: DateTime(2026, 8, 12),
                    status: ServiceStatus.completed,
                  ),
                  onEdit: () => firstEditCount += 1,
                  onDelete: () {},
                ),
                ServiceRecordTile(
                  applianceName: 'Kitchen refrigerator',
                  now: DateTime(2026, 8, 25),
                  record: ServiceRecord(
                    id: secondInternalId,
                    serviceDate: DateTime(2026, 8, 20),
                    createdAt: DateTime(2026, 8, 20),
                    status: ServiceStatus.completed,
                  ),
                  onEdit: () {},
                  onDelete: () => secondDeleteCount += 1,
                ),
              ],
            ),
          ),
        ),
      );

      final menus = find.byType(PopupMenuButton<String>);
      expect(menus, findsNWidgets(2));
      final menuSemantics = [
        for (var index = 0; index < 2; index++)
          _popupMenuControlSemantics(tester, menus.at(index)),
      ];
      final menuNames = [
        for (final node in menuSemantics) node.getSemanticsData().tooltip,
      ];
      expect(menuNames.toSet(), hasLength(2));
      expect(menuNames[0], contains('Kitchen refrigerator'));
      expect(menuNames[0], contains('serviced 12 August 2026'));
      expect(menuNames[1], contains('Kitchen refrigerator'));
      expect(menuNames[1], contains('serviced 20 August 2026'));
      for (final name in menuNames) {
        expect(name, isNot(contains(firstInternalId)));
        expect(name, isNot(contains(secondInternalId)));
      }
      for (final node in menuSemantics) {
        expect(node, isSemantics(isButton: true, hasTapAction: true));
      }

      await tester.tap(menus.first);
      await tester.pumpAndSettle();
      final firstEditName = tester
          .getSemantics(find.text('Edit'))
          .getSemanticsData()
          .label;
      final firstDeleteName = tester
          .getSemantics(find.text('Delete'))
          .getSemanticsData()
          .label;
      expect(firstEditName, contains('serviced 12 August 2026'));
      expect(firstDeleteName, contains('serviced 12 August 2026'));
      expect(firstEditName, isNot(contains(firstInternalId)));
      expect(firstDeleteName, isNot(contains(firstInternalId)));
      expect(
        tester.getSemantics(find.text('Edit')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(firstEditCount, 1);

      await tester.tap(menus.at(1));
      await tester.pumpAndSettle();
      final secondEditName = tester
          .getSemantics(find.text('Edit'))
          .getSemanticsData()
          .label;
      final secondDeleteName = tester
          .getSemantics(find.text('Delete'))
          .getSemanticsData()
          .label;
      expect(secondEditName, contains('serviced 20 August 2026'));
      expect(secondDeleteName, contains('serviced 20 August 2026'));
      expect(secondEditName, isNot(equals(firstEditName)));
      expect(secondDeleteName, isNot(equals(firstDeleteName)));
      expect(secondEditName, isNot(contains(secondInternalId)));
      expect(secondDeleteName, isNot(contains(secondInternalId)));
      expect(
        tester.getSemantics(find.text('Delete')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(secondDeleteCount, 1);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('same-day feedback has distinct safe status action contexts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semanticsHandle = tester.ensureSemantics();
    try {
      const firstInternalId = 'firestore-feedback-alpha';
      const secondInternalId = 'firestore-feedback-beta';
      const firstDocumentPath = 'feedback/internal-alpha-document';
      const secondDocumentPath = 'feedback/internal-beta-document';
      final repository = _FakeFeedbackAdminRepository(
        items: [
          AdminFeedbackItem(
            id: firstInternalId,
            documentPath: firstDocumentPath,
            uid: 'internal-user-alpha',
            category: FeedbackCategory.bug,
            message: 'Warranty expiry disappears after refresh.',
            createdAt: DateTime(2026, 8, 25, 9, 15),
          ),
          AdminFeedbackItem(
            id: secondInternalId,
            documentPath: secondDocumentPath,
            uid: 'internal-user-beta',
            category: FeedbackCategory.featureRequest,
            message: 'Add a reminder preview before saving.',
            createdAt: DateTime(2026, 8, 25, 14, 40),
          ),
        ],
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

      final menus = find.byType(PopupMenuButton<FeedbackWorkflowStatus>);
      expect(menus, findsNWidgets(2));
      final menuSemantics = [
        for (var index = 0; index < 2; index++)
          _popupMenuControlSemantics(tester, menus.at(index)),
      ];
      final actionNames = [
        for (final node in menuSemantics) node.getSemanticsData().tooltip,
      ];
      expect(actionNames.toSet(), hasLength(2));
      expect(
        actionNames.any(
          (name) =>
              name.contains('Bug feedback') &&
              name.contains('New') &&
              name.contains('Warranty expiry disappears') &&
              name.contains('25 August 2026 at 09:15'),
        ),
        isTrue,
      );
      expect(
        actionNames.any(
          (name) =>
              name.contains('Feature request feedback') &&
              name.contains('New') &&
              name.contains('Add a reminder preview') &&
              name.contains('25 August 2026 at 14:40'),
        ),
        isTrue,
      );
      for (final actionName in actionNames) {
        for (final internalValue in [
          firstInternalId,
          secondInternalId,
          firstDocumentPath,
          secondDocumentPath,
          'internal-user-alpha',
          'internal-user-beta',
        ]) {
          expect(actionName, isNot(contains(internalValue)));
        }
      }
      for (final node in menuSemantics) {
        expect(node, isSemantics(isButton: true, hasTapAction: true));
      }

      await tester.tap(menus.first);
      await tester.pumpAndSettle();
      expect(
        find.byType(PopupMenuItem<FeedbackWorkflowStatus>),
        findsNWidgets(FeedbackWorkflowStatus.values.length),
      );
      expect(
        tester.getSemantics(find.text('Dismissed')),
        isSemantics(isButton: true, hasTapAction: true),
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('search results announce count and filter selected state', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      final appliance = Appliance(
        id: 'search-appliance',
        name: 'Kitchen refrigerator',
        category: 'Refrigerator',
        brand: 'HomeVault Test',
        createdAt: DateTime(2026, 8, 20),
      );
      final store = await _storeWith(appliance);
      addTearDown(store.dispose);

      await tester.pumpWidget(
        AppScope(
          applianceStore: store,
          child: const MaterialApp(home: GlobalSearchScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('globalSearchField')),
        'Kitchen refrigerator',
      );
      await tester.pump();

      expect(
        tester.getSemantics(
          find.byKey(const Key('globalSearchResultAnnouncement')),
        ),
        isSemantics(label: '1 matching search result', isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.text('All')),
        isSemantics(label: 'All', isSelected: true),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('globalSearchResults')),
          matching: find.text('Kitchen refrigerator'),
        ),
        findsOneWidget,
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('document details expose headings without speaking filename', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      final document = _document(fileName: 'internal-generated-name.pdf');
      final appliance = Appliance(
        id: 'appliance-1',
        name: 'Kitchen refrigerator',
        category: 'Refrigerator',
        brand: 'Samsung',
        additionalDocuments: [document],
        createdAt: DateTime(2026, 8, 20),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentDetailsScreen(appliance: appliance, document: document),
        ),
      );

      expect(
        tester.getSemantics(find.text('File information')),
        isSemantics(label: 'File information', isHeader: true),
      );
      final fileInformation = tester
          .getSemantics(find.text(document.fileName))
          .getSemanticsData()
          .label;
      expect(fileInformation, contains('File name: Hidden for privacy'));
      expect(fileInformation, contains('Size'));
      expect(fileInformation, contains('Added'));
      expect(fileInformation, isNot(contains(document.fileName)));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('informative feedback images have a safe description', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semanticsHandle = tester.ensureSemantics();
    try {
      const transparentPng =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      final item = AdminFeedbackItem(
        id: 'feedback-1',
        documentPath: 'feedback/feedback-1',
        uid: 'user-1',
        category: FeedbackCategory.bug,
        message: 'The save action needs attention.',
        createdAt: DateTime(2026, 8, 25),
        screenshotFileName: 'internal-screenshot-name.png',
        screenshotBase64: transparentPng,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackDetailScreen(
            item: item,
            adminUid: 'admin-1',
            repository: _FakeFeedbackAdminRepository(),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Feedback screenshot'), findsOneWidget);
      expect(find.bySemanticsLabel(item.screenshotFileName!), findsNothing);
      expect(find.bySemanticsLabel(item.uid), findsNothing);
    } finally {
      semanticsHandle.dispose();
    }
  });
}

class _FakeFeedbackAdminRepository implements FeedbackAdminRepository {
  _FakeFeedbackAdminRepository({this.items = const []});

  final List<AdminFeedbackItem> items;

  @override
  Future<bool> isAdmin(String uid) async => true;

  @override
  Stream<List<AdminFeedbackItem>> watchFeedback() => Stream.value(items);

  @override
  Future<void> updateFeedback({
    required AdminFeedbackItem item,
    required String adminUid,
    FeedbackWorkflowStatus? status,
    FeedbackPriority? priority,
    String? adminNote,
  }) async {}
}
