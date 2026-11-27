import 'package:cloud_functions/cloud_functions.dart';

class AccountDeletionService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Future<DateTime> requestDeletion() async {
    final response =
        await _functions.httpsCallable('requestAccountDeletion').call();
    final data = Map<String, dynamic>.from(response.data as Map);
    final deleteAfter = data['deleteAfter'];
    if (deleteAfter is! num) {
      throw const FormatException(
        'The server returned an invalid account deletion deadline.',
      );
    }
    return DateTime.fromMillisecondsSinceEpoch(deleteAfter.toInt());
  }

  static Future<void> restoreDeletion() async {
    await _functions.httpsCallable('restoreAccountDeletion').call();
  }
}
