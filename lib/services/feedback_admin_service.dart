import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_feedback.dart';

abstract class FeedbackAdminRepository {
  Future<bool> isAdmin(String uid);

  Stream<List<AdminFeedbackItem>> watchFeedback();

  Future<void> updateFeedback({
    required AdminFeedbackItem item,
    required String adminUid,
    FeedbackWorkflowStatus? status,
    FeedbackPriority? priority,
    String? adminNote,
  });
}

class FirebaseFeedbackAdminRepository implements FeedbackAdminRepository {
  FirebaseFeedbackAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<bool> isAdmin(String uid) async {
    if (uid.trim().isEmpty) return false;
    try {
      final snapshot = await _firestore.collection('admins').doc(uid).get();
      return snapshot.exists && snapshot.data()?['enabled'] == true;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Stream<List<AdminFeedbackItem>> watchFeedback() {
    late StreamController<List<AdminFeedbackItem>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    centralSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? legacySubscription;

    var central = <AdminFeedbackItem>[];
    var legacy = <AdminFeedbackItem>[];

    void emit() {
      final merged = <String, AdminFeedbackItem>{};
      for (final item in [...central, ...legacy]) {
        merged[item.documentPath] = item;
      }
      final values = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(values);
    }

    controller = StreamController<List<AdminFeedbackItem>>(
      onListen: () {
        centralSubscription = _firestore
            .collection('feedback')
            .orderBy('createdAt', descending: true)
            .limit(250)
            .snapshots()
            .listen((snapshot) {
              central = snapshot.docs
                  .map(
                    (doc) =>
                        AdminFeedbackItem.fromSnapshot(doc, isLegacy: false),
                  )
                  .toList();
              emit();
            }, onError: controller.addError);

        legacySubscription = _firestore
            .collectionGroup('feedback')
            .orderBy('createdAt', descending: true)
            .limit(250)
            .snapshots()
            .listen(
              (snapshot) {
                legacy = snapshot.docs
                    .where((doc) => doc.reference.parent.parent != null)
                    .map(
                      (doc) =>
                          AdminFeedbackItem.fromSnapshot(doc, isLegacy: true),
                    )
                    .toList();
                emit();
              },
              onError: (_) {
                // Legacy feedback should never prevent the new central
                // dashboard from loading. New submissions live in /feedback.
                legacy = <AdminFeedbackItem>[];
                emit();
              },
            );
      },
      onCancel: () async {
        await centralSubscription?.cancel();
        await legacySubscription?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> updateFeedback({
    required AdminFeedbackItem item,
    required String adminUid,
    FeedbackWorkflowStatus? status,
    FeedbackPriority? priority,
    String? adminNote,
  }) async {
    final updates = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': adminUid,
    };
    if (status != null) updates['status'] = status.name;
    if (priority != null) updates['priority'] = priority.name;
    if (adminNote != null) updates['adminNote'] = adminNote.trim();

    await _firestore.doc(item.documentPath).update(updates);
  }
}
