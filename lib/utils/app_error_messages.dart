import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

String friendlyAuthError(Object error) {
  if (error is PlatformException) {
    if (error.code == 'channel-error') {
      return 'Google sign-in needs one more setup step. Please update the Android Firebase settings and try again.';
    }
    return _messageFromRawText(error.message) ??
        'We could not start Google sign-in. Please try again.';
  }

  if (error is FirebaseAuthException) {
    final String code = error.code.toLowerCase();
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This email is already linked to another sign-in method.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The sign-in details do not look right. Please try again.';
      case 'network-request-failed':
        return 'You seem to be offline. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled for this app yet.';
      case 'popup-closed-by-user':
      case 'web-context-cancelled':
        return 'Sign-in was cancelled. No changes were made.';
      case 'too-many-requests':
        return 'Too many sign-in attempts. Please wait a moment and try again.';
      case 'google_sign_in_unsupported':
        return 'Google sign-in is not supported on this device.';
      case 'missing_google_id_token':
        return 'Google did not finish the sign-in handoff. Please try again.';
      case 'invalid_email_domain':
        return error.message ?? 'Please use the required Google account.';
    }
    return _messageFromRawText(error.message) ??
        'We could not sign you in. Please try again.';
  }

  return _messageFromRawText(error.toString()) ??
      'We could not sign you in. Please try again.';
}

String friendlyAdminError(Object error) {
  if (error is FirebaseAuthException) {
    if (error.code == 'permission-denied') {
      return 'You do not have permission to make that admin change.';
    }
  }

  final String raw = error.toString().toLowerCase();
  if (raw.contains('permission-denied')) {
    return 'You do not have permission to make that admin change.';
  }
  if (raw.contains('network')) {
    return 'The admin change could not sync. Check your connection and try again.';
  }
  return 'The admin change could not be completed. Please try again.';
}

String friendlyFilePickerError(Object error) {
  final String raw = error.toString().toLowerCase();
  if (raw.contains('cancel')) {
    return 'File selection was cancelled.';
  }
  if (raw.contains('permission')) {
    return 'StudyMate does not have permission to use that file.';
  }
  return 'We could not use that file. Please choose another audio file.';
}

String? _messageFromRawText(String? message) {
  final String raw = message?.toLowerCase().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  if (raw.contains('googlesigninexceptioncode.canceled') ||
      raw.contains('sign_in_canceled') ||
      raw.contains('popup_closed_by_user')) {
    return 'Sign-in was cancelled. No changes were made.';
  }
  if (raw.contains('network')) {
    return 'You seem to be offline. Check your connection and try again.';
  }
  if (raw.contains('developer_error') || raw.contains('api_exception: 10')) {
    return 'Google sign-in needs one more setup step. Please check the app configuration.';
  }
  if (raw.contains('account reauth failed')) {
    return 'Google could not verify that account. Please choose the account again.';
  }
  return null;
}
