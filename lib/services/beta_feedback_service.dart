import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/app_build_info.dart';
import '../models/beta_feedback.dart';
import 'firebase_error_message.dart';

class SelectedFeedbackScreenshot {
  const SelectedFeedbackScreenshot({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;

  String get base64Data => base64Encode(bytes);
}

class BetaFeedbackService {
  BetaFeedbackService({
    FirebaseFirestore? firestore,
    DeviceInfoPlugin? deviceInfo,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  static const int maximumScreenshotBytes = 450 * 1024;

  final FirebaseFirestore _firestore;
  final DeviceInfoPlugin _deviceInfo;

  Future<SelectedFeedbackScreenshot?> pickScreenshot() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose an optional screenshot',
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final selected = result.files.single;
    Uint8List? bytes = selected.bytes;
    if (bytes == null && selected.path?.isNotEmpty == true) {
      bytes = await File(selected.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      throw const FeedbackSubmissionException(
        'The selected screenshot could not be read.',
      );
    }
    if (bytes.length > maximumScreenshotBytes) {
      throw const FeedbackSubmissionException(
        'The screenshot must be smaller than 450 KB.',
      );
    }

    return SelectedFeedbackScreenshot(fileName: selected.name, bytes: bytes);
  }

  Future<void> submit({
    required String uid,
    required BetaFeedback feedback,
  }) async {
    if (uid.trim().isEmpty) {
      throw const FeedbackSubmissionException(
        'Sign in before sending feedback.',
      );
    }
    if (!feedback.isValid) {
      throw const FeedbackSubmissionException(
        'Enter between 10 and 5000 characters.',
      );
    }

    try {
      final package = await PackageInfo.fromPlatform();
      final android = await _deviceInfo.androidInfo;

      await _firestore.collection('users').doc(uid).collection('feedback').add({
        'uid': uid,
        'category': feedback.category.name,
        'message': feedback.message.trim(),
        'appVersion': package.version,
        'buildNumber': package.buildNumber,
        'releaseNumber': AppBuildInfo.releaseNumber,
        'platform': 'android',
        'deviceManufacturer': android.manufacturer,
        'deviceModel': android.model,
        'androidVersion': android.version.release,
        'androidSdk': android.version.sdkInt,
        'screenshotFileName': feedback.screenshotFileName,
        'screenshotBase64': feedback.screenshotBase64,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (error is FeedbackSubmissionException) rethrow;
      throw FeedbackSubmissionException(
        friendlyFirebaseError(
          error,
          fallback: 'Feedback could not be sent. Please try again.',
        ),
        error,
      );
    }
  }
}

class FeedbackSubmissionException implements Exception {
  const FeedbackSubmissionException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
