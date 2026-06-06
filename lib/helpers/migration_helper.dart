// lib/helpers/migration_helper.dart
import 'package:hive/hive.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;

class MigrationHelper {
  // Main function to run all migrations, now accepts open boxes
  static Future<void> runAllMigrations({
    required Box<Account> accountsBox,
    required Box<model.Transaction> transactionsBox,
    required Box<Profession> professionsBox,
  }) async {
    try {
      print("🚀 Starting database migrations with open boxes...");

      // Migration 1: Add new fields to existing professions (V1 to V2)
      await _migrateProfessionsV1ToV2(professionsBox);

      // Migration 2: Clean up any data issues
      await _cleanupOrphanedData(
        accountsBox: accountsBox,
        transactionsBox: transactionsBox,
        professionsBox: professionsBox,
      );

      print("✅ All migrations completed successfully!");
    } catch (e) {
      print("❌ Migration failed: $e");
      // Don't throw, just log. App should still work.
    }
  }

  // Profession model V1 to V2 migration, accepts an open box
  static Future<void> _migrateProfessionsV1ToV2(Box<Profession> box) async {
    try {
      final professions = box.values.toList();

      if (professions.isEmpty) {
        print("📭 No professions found to migrate");
        return;
      }

      print("🔄 Found ${professions.length} professions to check for migration from V1 to V2");
      int migratedCount = 0;
      int skippedCount = 0;
      final Map<dynamic, Profession> professionsToUpdate = {};


      for (var oldProfession in professions) {
        bool needsMigration = false;
        
        // Simple check: if seasonKey is null or empty but season has value, it needs key generation.
        if (oldProfession.season.isNotEmpty && (oldProfession.seasonKey == null || oldProfession.seasonKey!.isEmpty)) {
            needsMigration = true;
        }

        if (!needsMigration) {
          skippedCount++;
          continue;
        }

        final migratedProfession = oldProfession.copyWith(
          updatedAt: DateTime.now(),
          seasonKey: _generateSeasonKey(oldProfession.name, oldProfession.season),
        );
        
        professionsToUpdate[oldProfession.id] = migratedProfession;
        migratedCount++;
        print("  ✅ Queued for migration: ${oldProfession.name} (${oldProfession.season})");
      }
      
      if (professionsToUpdate.isNotEmpty) {
        await box.putAll(professionsToUpdate);
      }

      print("📊 Profession Migration Report:");
      print("   Total professions checked: ${professions.length}");
      print("   Migrated: $migratedCount");
      print("   Skipped (already V2): $skippedCount");

    } catch (e) {
      print("❌ Profession migration error: $e");
      throw e;
    }
  }

  // Generate season key
  static String _generateSeasonKey(String name, String season) {
    if (season.isEmpty) return "";
    String cleanName = name.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^\w_]'), '');
    String cleanSeason = season.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll(RegExp(r'[^\w_]'), '');
    return "${cleanName}_$cleanSeason";
  }

  // Clean up orphaned data, accepting open boxes
  static Future<void> _cleanupOrphanedData({
    required Box<Account> accountsBox,
    required Box<model.Transaction> transactionsBox,
    required Box<Profession> professionsBox,
  }) async {
    try {
      print("🧹 Cleaning up orphaned data...");
      int cleanedTxCount = 0;
      int fixedProfessionCount = 0;
      
      final List<dynamic> transactionsToDelete = [];

      // Clean transactions with invalid account IDs
      final allAccountKeys = accountsBox.keys.toSet();
      for (var tx in transactionsBox.values) {
        if (!allAccountKeys.contains(tx.accountId)) {
          transactionsToDelete.add(tx.key); // Use tx.key as it's a HiveObject
          cleanedTxCount++;
          print("  🗑️ Queued orphaned transaction for deletion: ID ${tx.id}");
        }
      }

      if (transactionsToDelete.isNotEmpty) {
        await transactionsBox.deleteAll(transactionsToDelete);
      }

      // Clean professions with invalid data (e.g., null fields that should not be)
      final Map<dynamic, Profession> professionsToUpdate = {};
      for (var profession in professionsBox.values) {
        if (profession.seasonKey == null) {
          final fixedProfession = profession.copyWith(
            seasonKey: profession.season.isNotEmpty
                ? _generateSeasonKey(profession.name, profession.season)
                : "",
          );
          professionsToUpdate[profession.id] = fixedProfession;
          fixedProfessionCount++;
          print("  🔧 Queued profession for fixing: ${profession.name}");
        }
      }
      
      if(professionsToUpdate.isNotEmpty) {
        await professionsBox.putAll(professionsToUpdate);
      }

      print("✅ Cleanup complete. Deleted $cleanedTxCount transactions and fixed $fixedProfessionCount professions.");

    } catch (e) {
      print("⚠️ Cleanup error: $e");
      // Don't throw, cleanup is non-critical
    }
  }
  
  // Database health check, accepts OPEN boxes
  static Future<Map<String, dynamic>> checkDatabaseHealth({
      required Box<Profession> professionsBox,
  }) async {
    final report = <String, dynamic>{
      'status': 'healthy',
      'issues': [],
      'stats': {},
    };

    try {
      final professions = professionsBox.values.toList();
      report['stats']['professions_count'] = professions.length;

      final v1Professions = professions.where((p) =>
        p.season.isNotEmpty && (p.seasonKey == null || p.seasonKey!.isEmpty)
      ).toList();

      if (v1Professions.isNotEmpty) {
        report['issues'].add('Found ${v1Professions.length} V1 professions that need migration');
        report['status'] = 'needs_migration';
      }
      
    } catch (e) {
      report['status'] = 'error';
      report['issues'].add('Error checking database: $e');
    }

    return report;
  }
}
