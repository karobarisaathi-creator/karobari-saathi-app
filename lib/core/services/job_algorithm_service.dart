import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:geolocator/geolocator.dart';

class JobAlgorithmService {
  // 1. میعاد ختم ہونے والی جابز کو فلٹر کرنا
  List<JobPost> filterExpired(List<JobPost> jobs) {
    final now = DateTime.now();
    return jobs
        .where((job) => job.deadline == null || job.deadline!.isAfter(now))
        .toList();
  }

  // 2. متعلقہ پیشوں کی لسٹ حاصل کرنا
  List<String> getRelatedCategories(String category) {
    final Map<String, List<String>> relatedMap = {
      'electrician': [
        'plumber',
        'carpenter',
        'solar_installer',
        'ac_technician'
      ],
      'plumber': ['electrician', 'mason', 'tile_fixer'],
      'mason': ['tile_fixer', 'plaster', 'painter', 'carpenter'],
      'carpenter': ['painter', 'mason', 'interior_designer'],
      'software_dev': ['web_designer', 'mobile_app_developer', 'it_support'],
      'mechanic': ['bike_mechanic', 'welder', 'generator_mechanic'],
      'driver': ['delivery_boy', 'heavy_driver'],
    };
    return relatedMap[category] ?? [];
  }

  // 3. جاب کی "شدت" یا Urgency کا اندازہ لگانا
  String getUrgencyLabel(DateTime? deadline, bool isUrdu) {
    if (deadline == null) return '';
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    if (daysLeft <= 1) return isUrdu ? 'انتہائی ضروری' : 'Urgent';
    if (daysLeft <= 3) return isUrdu ? 'جلد ضرورت' : 'High Priority';
    return '';
  }

  // 4. سمارٹ ترتیب (Smart Sorting)
  // پیشہ، متعلقہ category، urgency اور تازگی کو ملا کر score بنائیں۔
  List<JobPost> applySmartSort({
    required List<JobPost> jobs,
    String? artisanProfession,
    String? currentUserId,
    double? artisanLat,
    double? artisanLng,
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

      // 3. Proximity (Location Weight) - 🆕 
      if (artisanLat != null && artisanLng != null && job.latitude != null && job.longitude != null) {
        final distance = Geolocator.distanceBetween(
          artisanLat, artisanLng, job.latitude!, job.longitude!
        ) / 1000; // in km

        if (distance <= 5) {
          value += 25; // Super close
        } else if (distance <= 15) {
          value += 15; // Within city
        } else if (distance <= 30) {
          value += 5; // Nearby
        }
      }

      // 4. Urgency
      if (job.deadline != null) {
        final daysLeft = job.deadline!.difference(now).inDays;
        if (daysLeft <= 1) {
          value += 15;
        } else if (daysLeft <= 3) {
          value += 10;
        }
      }

      // 5. Freshness
      final ageInDays = now.difference(job.createdAt).inDays;
      value += (10 - ageInDays).clamp(0, 10).toDouble();
      
      return value;
    }

    final sortedJobs = List<JobPost>.from(jobs);
    sortedJobs.sort((a, b) => score(b).compareTo(score(a)));
    return sortedJobs;
  }
}
