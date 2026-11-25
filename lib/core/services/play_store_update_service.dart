import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

class PlayStoreUpdateService {
  static const int _immediateUpdatePriority = 4;
  StreamSubscription<InstallStatus>? _installSubscription;
  bool _isCompletingFlexibleUpdate = false;

  Future<void> checkForUpdate() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        await _resumeUpdate(updateInfo);
        return;
      }

      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (updateInfo.updatePriority >= _immediateUpdatePriority &&
          updateInfo.immediateUpdateAllowed) {
        await _performImmediateUpdate();
        return;
      }

      if (updateInfo.flexibleUpdateAllowed) {
        _listenForFlexibleUpdate();
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result != AppUpdateResult.success) {
          await _installSubscription?.cancel();
          _installSubscription = null;
          debugPrint('Google Play flexible update was not completed: $result');
        }
        return;
      }

      debugPrint(
        'Google Play update is available, but no update flow is allowed. '
        'Immediate preconditions: ${updateInfo.immediateAllowedPreconditions}; '
        'flexible preconditions: ${updateInfo.flexibleAllowedPreconditions}',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Google Play in-app update failed (${error.code}): ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      debugPrint('Could not check for a Google Play update: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _resumeUpdate(AppUpdateInfo updateInfo) async {
    if (updateInfo.installStatus == InstallStatus.downloaded) {
      await _completeFlexibleUpdate();
      return;
    }

    if (updateInfo.installStatus == InstallStatus.pending ||
        updateInfo.installStatus == InstallStatus.downloading ||
        updateInfo.installStatus == InstallStatus.installing) {
      return;
    }

    if (updateInfo.immediateUpdateAllowed) {
      await _performImmediateUpdate();
    }
  }

  void _listenForFlexibleUpdate() {
    if (_installSubscription != null) return;
    _installSubscription = InAppUpdate.installUpdateListener.listen(
      (status) {
        if (status == InstallStatus.downloaded) {
          unawaited(_completeFlexibleUpdate());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Google Play update status listener failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  Future<void> _completeFlexibleUpdate() async {
    if (_isCompletingFlexibleUpdate) return;
    _isCompletingFlexibleUpdate = true;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } finally {
      _isCompletingFlexibleUpdate = false;
    }
  }

  Future<void> _performImmediateUpdate() async {
    final result = await InAppUpdate.performImmediateUpdate();
    if (result != AppUpdateResult.success) {
      debugPrint('Google Play immediate update was not completed: $result');
    }
  }

  Future<void> dispose() async {
    await _installSubscription?.cancel();
    _installSubscription = null;
  }
}
