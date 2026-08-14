import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';

class JobAlgorithmService {
  // 1. میعاد ختم ہونے والی جابز کو فلٹر کرنا
  List<JobPost> filterExpired(List<JobPost> jobs) {
    final now = DateTime.now();
    return jobs.where((job) => job.deadline.isAfter(now)).toList();
  }

  // 2. متعلقہ پیشوں کی لسٹ حاصل کرنا
  List<String> getRelatedCategories(String category) {
    final Map<String, List<String>> relatedMap = {
      'electrician': ['plumber', 'carpenter', 'solar_installer', 'ac_technician'],
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
  String getUrgencyLabel(DateTime deadline, bool isUrdu) {
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    if (daysLeft <= 1) return isUrdu ? 'انتہائی ضروری' : 'Urgent';
    if (daysLeft <= 3) return isUrdu ? 'جلد ضرورت' : 'High Priority';
    return '';
  }

  // 4. سمارٹ ترتیب (Smart Sorting)
  // اپنے کام پہلے، پھر متعلقہ پیشے، پھر باقی
  List<JobPost> applySmartSort(List<JobPost> jobs, String? artisanProfession, String? currentUserId) {
    final List<JobPost> myJobs = [];
    final List<JobPost> matchingJobs = [];
    final List<JobPost> relatedJobs = [];
    final List<JobPost> others = [];

    final relatedCategories = artisanProfession != null ? getRelatedCategories(artisanProfession) : [];

    for (var job in jobs) {
      if (currentUserId != null && job.customerId == currentUserId) {
        myJobs.add(job);
      } else if (artisanProfession != null && job.category == artisanProfession) {
        matchingJobs.add(job);
      } else if (relatedCategories.contains(job.category)) {
        relatedJobs.add(job);
      } else {
        others.add(job);
      }
    }

    // ترتیب: اپنے کام > میچنگ کام > متعلقہ کام > باقی تمام
    return [...myJobs, ...matchingJobs, ...relatedJobs, ...others];
  }
}
