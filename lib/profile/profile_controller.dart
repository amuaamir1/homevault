import 'package:flutter/foundation.dart';

import '../models/authenticated_user.dart';
import '../models/user_profile.dart';
import '../services/crash_reporting_service.dart';
import '../services/firebase_error_message.dart';
import 'profile_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({UserProfileRepository? repository})
    : _repository = repository ?? FirestoreUserProfileRepository();

  ProfileController.loadedForTesting(UserProfile profile)
    : _repository = MemoryUserProfileRepository(initialProfile: profile),
      _profile = profile,
      _loadedUid = profile.uid,
      _isLoading = false,
      _isTestController = true;

  final UserProfileRepository _repository;

  UserProfile? _profile;
  String? _loadedUid;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTestController = false;
  String? _errorMessage;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get hasCompleteProfile => _profile?.isComplete == true;

  /// True only after this controller has finished resolving the profile for
  /// the currently authenticated Firebase user.
  ///
  /// A null profile can be a valid resolved state for a brand-new account, so
  /// routing must not use `profile == null` alone to decide that setup is
  /// required.
  bool isResolvedForUser(String uid) => !_isLoading && _loadedUid == uid;

  Future<void> loadForUser(AuthenticatedUser user, {bool force = false}) async {
    if (_isTestController) return;
    if (!force && _loadedUid == user.uid && !_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    _loadedUid = user.uid;
    notifyListeners();

    try {
      final loaded = await _repository.loadProfile(user.uid);
      if (_loadedUid != user.uid) return;

      if (loaded == null) {
        _profile = null;
      } else {
        _profile = loaded.copyWith(
          uid: user.uid,
          email: user.email.isNotEmpty ? user.email : loaded.email,
          phoneNumber: loaded.phoneNumber.isNotEmpty
              ? loaded.phoneNumber
              : user.phoneNumber,
        );
      }
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Loading the user profile',
      );
      if (_loadedUid == user.uid) {
        _errorMessage = friendlyFirebaseError(
          error,
          fallback:
              'Your profile could not be loaded. Check the internet connection and try again.',
        );
      }
    } finally {
      if (_loadedUid == user.uid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> saveProfile(UserProfile profile) async {
    if (_isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final saved = profile.copyWith(
        createdAt: profile.createdAt ?? now,
        updatedAt: now,
      );
      await _repository.saveProfile(saved);
      _profile = saved;
      _loadedUid = saved.uid;
      return true;
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Saving the user profile',
      );
      _errorMessage = friendlyFirebaseError(
        error,
        fallback:
            'Your profile could not be saved. Check the internet connection and try again.',
      );
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clear() {
    _profile = null;
    _loadedUid = null;
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
  }
}
