import 'package:account_app/core/models/job_post_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:account_app/core/config/professions_config.dart';

class JobAlgorithmService {
  // متعلقہ پیشوں کی لسٹ حاصل کرنا
  List<String> getRelatedCategories(String category) {
    return ProfessionsConfig.relatedProfessions[category] ?? [];
  }

  // پیشہ، متعلقہ category، مقام اور تازگی کی بنیاد پر ترتیب دیں۔
  List<JobPost> applySmartSort({
    required List<JobPost> jobs,
    String? artisanProfession,
    String? currentUserId,
    double? artisanLat,
    double? artisanLng,
    double? artisanRating,
  }) {
    final relatedCategories = artisanProfession != null
        ? getRelatedCategories(artisanProfession)
        : <String>[];
    final now = DateTime.now();

    double score(JobPost job) {
      var value = 0.0;

      // 1. Own job (Penalty to move to bottom if browsing)
      if (currentUserId != null && job.customerId == currentUserId) {
        value -= 100;
      }

      // 2. Profession Match (High Weight)
      if (artisanProfession != null &&
          job.categories.contains(artisanProfession)) {
        value += 35;
      } else if (job.categories
          .any((category) => relatedCategories.contains(category))) {
        value += 20;
      }

      // 3. Proximity (Location Weight)
      if (artisanLat != null &&
          artisanLng != null &&
          job.latitude != null &&
          job.longitude != null) {
        final distance = Geolocator.distanceBetween(
                artisanLat, artisanLng, job.latitude!, job.longitude!) /
            1000; // in km

        if (distance <= 5) {
          value += 25; // Super close
        } else if (distance <= 15) {
          value += 15; // Within city
        } else if (distance <= 30) {
          value += 5; // Nearby
        }
      }

      // Artisan rating: up to 10 points.
      if (artisanRating != null && artisanRating > 0) {
        value += (artisanRating.clamp(0, 5) / 5) * 10;
      }

      // 5. Detailed scope
      if ((job.detailedScope ?? job.description).trim().length >= 40) {
        value += 10;
      }

      // 6. Visual details
      if (job.images.isNotEmpty) {
        value += 10;
      }

      // Freshness
      final ageInDays = now.difference(job.createdAt).inDays;
      value += (10 - ageInDays).clamp(0, 10).toDouble();

      return value;
    }

    final sortedJobs = List<JobPost>.from(jobs);
    sortedJobs.sort((a, b) => score(b).compareTo(score(a)));
    return sortedJobs;
  }
}
