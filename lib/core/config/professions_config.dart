import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/profession_model.dart';

class MasterProfession {
  final String id;
  final String name;
  final String nameUrdu;
  final IconData icon;
  final String categoryName;
  final String categoryUrdu;
  final ProfessionCategory categoryType;
  final String defaultUnit;

  const MasterProfession({
    required this.id,
    required this.name,
    required this.nameUrdu,
    required this.icon,
    required this.categoryName,
    required this.categoryUrdu,
    required this.categoryType,
    this.defaultUnit = 'unit',
  });
}

class ProfessionGroup {
  final String id;
  final String name;
  final String nameUrdu;
  final IconData icon;
  final ProfessionCategory categoryType;

  const ProfessionGroup({
    required this.id,
    required this.name,
    required this.nameUrdu,
    required this.icon,
    required this.categoryType,
  });
}

class ProfessionsConfig {
  static const List<ProfessionGroup> professionGroups = [
    ProfessionGroup(
      id: 'agriculture',
      name: 'Agriculture & Livestock',
      nameUrdu: 'زراعت اور مویشی',
      icon: Icons.agriculture,
      categoryType: ProfessionCategory.agriculture,
    ),
    ProfessionGroup(
      id: 'retail',
      name: 'Trade & Retail',
      nameUrdu: 'تجارت اور دکان',
      icon: Icons.storefront,
      categoryType: ProfessionCategory.retail,
    ),
    ProfessionGroup(
      id: 'services',
      name: 'Services & Skilled Work',
      nameUrdu: 'خدمات اور ہنر',
      icon: Icons.handyman,
      categoryType: ProfessionCategory.services,
    ),
    ProfessionGroup(
      id: 'construction',
      name: 'Construction & Projects',
      nameUrdu: 'تعمیرات اور منصوبے',
      icon: Icons.construction,
      categoryType: ProfessionCategory.construction,
    ),
    ProfessionGroup(
      id: 'manufacturing',
      name: 'Manufacturing & Production',
      nameUrdu: 'کارخانہ اور پیداوار',
      icon: Icons.factory,
      categoryType: ProfessionCategory.manufacturing,
    ),
    ProfessionGroup(
      id: 'transportation',
      name: 'Transport & Delivery',
      nameUrdu: 'ٹرانسپورٹ اور ترسیل',
      icon: Icons.local_shipping,
      categoryType: ProfessionCategory.transportation,
    ),
    ProfessionGroup(
      id: 'technology',
      name: 'Technology',
      nameUrdu: 'ٹیکنالوجی',
      icon: Icons.memory,
      categoryType: ProfessionCategory.technology,
    ),
    ProfessionGroup(
      id: 'education',
      name: 'Education',
      nameUrdu: 'تعلیم',
      icon: Icons.school,
      categoryType: ProfessionCategory.education,
    ),
    ProfessionGroup(
      id: 'healthcare',
      name: 'Healthcare',
      nameUrdu: 'صحت',
      icon: Icons.health_and_safety,
      categoryType: ProfessionCategory.healthcare,
    ),
    ProfessionGroup(
      id: 'other',
      name: 'Other',
      nameUrdu: 'دیگر',
      icon: Icons.work,
      categoryType: ProfessionCategory.general,
    ),
  ];

  static ProfessionCategory categoryTypeFor(Profession profession) {
    if (profession.categoryType != ProfessionCategory.general) {
      return profession.categoryType;
    }

    final description = profession.description ?? '';
    if (!description.startsWith('ICON:')) return profession.categoryType;
    final iconKey = description.substring(5).split('|').first;
    final group =
        professionGroups.where((item) => item.id == iconKey).firstOrNull;
    if (group != null) return group.categoryType;

    return allProfessions
            .where((item) => item.id == iconKey)
            .firstOrNull
            ?.categoryType ??
        profession.categoryType;
  }

  static List<String> defaultCategories(
    ProfessionCategory categoryType, {
    required bool isUrdu,
  }) {
    final categories = switch (categoryType) {
      ProfessionCategory.agriculture => [
          ['Crop Sale', 'فصل کی فروخت'],
          ['Livestock Sale', 'مویشیوں کی فروخت'],
          ['Seeds', 'بیج'],
          ['Fertilizer', 'کھاد'],
          ['Pesticides', 'زرعی ادویات'],
          ['Irrigation', 'آبپاشی'],
          ['Labor', 'مزدوری'],
          ['Land Rent', 'زمین کا کرایہ'],
          ['Transport', 'ٹرانسپورٹ'],
          ['Other', 'دیگر'],
        ],
      ProfessionCategory.retail => [
          ['Sales', 'فروخت'],
          ['Wholesale Sales', 'تھوک فروخت'],
          ['Stock Purchase', 'مال کی خریداری'],
          ['Supplier Payment', 'سپلائر کی ادائیگی'],
          ['Rent', 'کرایہ'],
          ['Wages', 'اجرت'],
          ['Utilities', 'بلز'],
          ['Transport', 'ٹرانسپورٹ'],
          ['Other', 'دیگر'],
        ],
      ProfessionCategory.construction => [
          ['Project Payment', 'پروجیکٹ کی ادائیگی'],
          ['Labor', 'مزدوری'],
          ['Cement', 'سیمنٹ'],
          ['Bricks', 'اینٹیں'],
          ['Steel', 'سریا'],
          ['Other Materials', 'دیگر میٹریل'],
          ['Transport', 'ٹرانسپورٹ'],
          ['Equipment', 'اوزار اور مشینری'],
          ['Other', 'دیگر'],
        ],
      ProfessionCategory.manufacturing => [
          ['Product Sales', 'مصنوعات کی فروخت'],
          ['Raw Materials', 'خام مال'],
          ['Packaging', 'پیکنگ'],
          ['Labor', 'مزدوری'],
          ['Machinery', 'مشینری'],
          ['Utilities', 'بلز'],
          ['Transport', 'ٹرانسپورٹ'],
          ['Other', 'دیگر'],
        ],
      ProfessionCategory.transportation => [
          ['Trip Fare', 'سفر کا کرایہ'],
          ['Delivery Income', 'ڈیلیوری کی آمدنی'],
          ['Fuel', 'ایندھن'],
          ['Vehicle Repair', 'گاڑی کی مرمت'],
          ['Vehicle Rent', 'گاڑی کا کرایہ'],
          ['Tolls', 'ٹول ٹیکس'],
          ['Driver Wages', 'ڈرائیور کی اجرت'],
          ['Other', 'دیگر'],
        ],
      ProfessionCategory.technology => [
          ['Project Income', 'پروجیکٹ کی آمدنی'],
          ['Consulting', 'مشاورت'],
          ['Subscription', 'سبسکرپشن'],
          ['Software', 'سافٹ ویئر'],
          ['Equipment', 'آلات'],
          ['Internet', 'انٹرنیٹ'],
          ['Contractor', 'کنٹریکٹر'],
          ['Other', 'دیگر'],
        ],
      ProfessionCategory.education => [
          ['Tuition Fee', 'ٹیوشن فیس'],
          ['Course Fee', 'کورس فیس'],
          ['Books', 'کتابیں'],
          ['Supplies', 'تعلیمی سامان'],
          ['Rent', 'کرایہ'],
          ['Utilities', 'بلز'],
          ['Other', 'دیگر'],
        ],
      ProfessionCategory.healthcare => [
          ['Consultation Fee', 'معائنہ فیس'],
          ['Treatment Fee', 'علاج کی فیس'],
          ['Medicine', 'ادویات'],
          ['Medical Supplies', 'طبی سامان'],
          ['Equipment', 'طبی آلات'],
          ['Rent', 'کرایہ'],
          ['Utilities', 'بلز'],
          ['Other', 'دیگر'],
        ],
      ProfessionCategory.services => [
          ['Service Income', 'سروس کی آمدنی'],
          ['Labor', 'مزدوری'],
          ['Materials', 'سامان'],
          ['Tools', 'اوزار'],
          ['Repair', 'مرمت'],
          ['Transport', 'ٹرانسپورٹ'],
          ['Rent', 'کرایہ'],
          ['Other', 'دیگر'],
        ],
      ProfessionCategory.general => [
          ['Sales', 'فروخت'],
          ['Service Income', 'سروس کی آمدنی'],
          ['Supplies', 'سامان'],
          ['Labor', 'مزدوری'],
          ['Rent', 'کرایہ'],
          ['Transport', 'ٹرانسپورٹ'],
          ['Utilities', 'بلز'],
          ['Other', 'دیگر'],
        ],
    };

    return categories.map((category) => category[isUrdu ? 1 : 0]).toList();
  }

  static List<MasterProfession> get allProfessions => [
        // --- تعمیرات اور ہارڈویئر (Construction & Hardware) ---
        MasterProfession(
          id: 'mason',
          name: 'Mason / Mistri',
          nameUrdu: 'راج / مستری',
          icon: PhosphorIcons.wall(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
          defaultUnit: 'پروجیکٹ',
        ),
        MasterProfession(
          id: 'plumber',
          name: 'Plumber',
          nameUrdu: 'پلمبر',
          icon: PhosphorIcons.wrench(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),
        MasterProfession(
          id: 'electrician',
          name: 'Electrician',
          nameUrdu: 'الیکٹریشن',
          icon: PhosphorIcons.lightning(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),
        MasterProfession(
          id: 'carpenter',
          name: 'Carpenter',
          nameUrdu: 'ترکھان (لکڑی کا کام)',
          icon: PhosphorIcons.hammer(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),
        MasterProfession(
          id: 'painter',
          name: 'Painter',
          nameUrdu: 'پینٹر',
          icon: PhosphorIcons.paintBrushBroad(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),
        MasterProfession(
          id: 'welder',
          name: 'Welder',
          nameUrdu: 'ویلڈر',
          icon: PhosphorIcons.fire(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),
        MasterProfession(
          id: 'tile_fixer',
          name: 'Tile Fixer',
          nameUrdu: 'ٹائل فکسر',
          icon: PhosphorIcons.gridFour(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),
        MasterProfession(
          id: 'plaster',
          name: 'Plasterer',
          nameUrdu: 'پلاسٹر ماہر',
          icon: PhosphorIcons.paintRoller(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),
        MasterProfession(
          id: 'steel_fixer',
          name: 'Steel Fixer',
          nameUrdu: 'سٹیل فکسر',
          icon: PhosphorIcons.stairs(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),
        MasterProfession(
          id: 'aluminum_worker',
          name: 'Aluminum Worker',
          nameUrdu: 'ایلومینیم کا کام',
          icon: PhosphorIcons.frameCorners(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),
        MasterProfession(
          id: 'glass_worker',
          name: 'Glass Worker',
          nameUrdu: 'شیشے کا کام',
          icon: PhosphorIcons.selectionAll(),
          categoryName: 'Construction & Hardware',
          categoryUrdu: 'تعمیرات اور ہارڈویئر',
          categoryType: ProfessionCategory.construction,
        ),

        // --- آئی ٹی اور سافٹ ویئر (IT & Software) ---
        MasterProfession(
          id: 'software_dev',
          name: 'Software Developer',
          nameUrdu: 'سوفٹ ویئر ڈویلپر',
          icon: PhosphorIcons.code(),
          categoryName: 'IT & Software',
          categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
          categoryType: ProfessionCategory.technology,
          defaultUnit: 'پروجیکٹ',
        ),
        MasterProfession(
          id: 'web_designer',
          name: 'Web Designer',
          nameUrdu: 'ویب ڈیزائنر',
          icon: PhosphorIcons.browser(),
          categoryName: 'IT & Software',
          categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
          categoryType: ProfessionCategory.technology,
        ),
        MasterProfession(
          id: 'graphic_designer',
          name: 'Graphic Designer',
          nameUrdu: 'گرافک ڈیزائنر',
          icon: PhosphorIcons.palette(),
          categoryName: 'IT & Software',
          categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
          categoryType: ProfessionCategory.technology,
        ),
        MasterProfession(
          id: 'digital_marketer',
          name: 'Digital Marketer',
          nameUrdu: 'ڈیجیٹل مارکیٹنگ',
          icon: PhosphorIcons.megaphone(),
          categoryName: 'IT & Software',
          categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
          categoryType: ProfessionCategory.technology,
        ),
        MasterProfession(
          id: 'video_editor',
          name: 'Video Editor',
          nameUrdu: 'ویڈیو ایڈیٹر',
          icon: PhosphorIcons.videoCamera(),
          categoryName: 'IT & Software',
          categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
          categoryType: ProfessionCategory.technology,
        ),
        MasterProfession(
          id: 'data_entry',
          name: 'Data Entry Operator',
          nameUrdu: 'ڈیٹا اینٹری آپریٹر',
          icon: PhosphorIcons.keyboard(),
          categoryName: 'IT & Software',
          categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
          categoryType: ProfessionCategory.technology,
        ),
        MasterProfession(
          id: 'seo_expert',
          name: 'SEO Expert',
          nameUrdu: 'SEO ایکسپرٹ',
          icon: PhosphorIcons.magnifyingGlassPlus(),
          categoryName: 'IT & Software',
          categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
          categoryType: ProfessionCategory.technology,
        ),
        MasterProfession(
          id: 'mobile_app_developer',
          name: 'Mobile App Developer',
          nameUrdu: 'موبائل ایپ ڈویلپر',
          icon: PhosphorIcons.deviceMobile(),
          categoryName: 'IT & Software',
          categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
          categoryType: ProfessionCategory.technology,
        ),

        // --- مرمت اور مکینک (Repair & Mechanics) ---
        MasterProfession(
          id: 'mobile_repair',
          name: 'Mobile Repairing',
          nameUrdu: 'موبائل ریپیئرنگ',
          icon: PhosphorIcons.deviceMobile(),
          categoryName: 'Repair & Mechanics',
          categoryUrdu: 'مرمت اور مکینک',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'laptop_repair',
          name: 'Computer / Laptop Repair',
          nameUrdu: 'کمپیوٹر / لیپ ٹاپ ریپیئر',
          icon: PhosphorIcons.laptop(),
          categoryName: 'Repair & Mechanics',
          categoryUrdu: 'مرمت اور مکینک',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'ac_technician',
          name: 'AC Technician',
          nameUrdu: 'AC ٹیکنیشن',
          icon: PhosphorIcons.snowflake(),
          categoryName: 'Repair & Mechanics',
          categoryUrdu: 'مرمت اور مکینک',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'solar_installer',
          name: 'Solar Installer',
          nameUrdu: 'سولر انسٹالر',
          icon: PhosphorIcons.sun(),
          categoryName: 'Repair & Mechanics',
          categoryUrdu: 'مرمت اور مکینک',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'mechanic',
          name: 'Car Mechanic',
          nameUrdu: 'گاڑیوں کا مکینک',
          icon: PhosphorIcons.engine(),
          categoryName: 'Repair & Mechanics',
          categoryUrdu: 'مرمت اور مکینک',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'bike_mechanic',
          name: 'Bike Mechanic',
          nameUrdu: 'بائیک مکینک',
          icon: PhosphorIcons.bicycle(),
          categoryName: 'Repair & Mechanics',
          categoryUrdu: 'مرمت اور مکینک',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'cctv_installer',
          name: 'CCTV Installer',
          nameUrdu: 'کیمرہ انسٹالر (CCTV)',
          icon: PhosphorIcons.cameraPlus(),
          categoryName: 'Repair & Mechanics',
          categoryUrdu: 'مرمت اور مکینک',
          categoryType: ProfessionCategory.services,
        ),

        // --- زراعت اور مویشی (Agriculture & Livestock) ---
        MasterProfession(
          id: 'farming',
          name: 'Farming / Agriculture',
          nameUrdu: 'کاشتکاری',
          icon: PhosphorIcons.plant(),
          categoryName: 'Agriculture & Livestock',
          categoryUrdu: 'زراعت اور مویشی',
          categoryType: ProfessionCategory.agriculture,
          defaultUnit: 'من',
        ),
        MasterProfession(
          id: 'agri_expert',
          name: 'Agriculture Expert',
          nameUrdu: 'ماہرِ زراعت',
          icon: PhosphorIcons.plant(),
          categoryName: 'Agriculture & Livestock',
          categoryUrdu: 'زراعت اور مویشی',
          categoryType: ProfessionCategory.agriculture,
          defaultUnit: 'کلو',
        ),
        MasterProfession(
          id: 'gardener',
          name: 'Gardener',
          nameUrdu: 'مالی',
          icon: PhosphorIcons.leaf(),
          categoryName: 'Agriculture & Livestock',
          categoryUrdu: 'زراعت اور مویشی',
          categoryType: ProfessionCategory.agriculture,
        ),
        MasterProfession(
          id: 'livestock_expert',
          name: 'Livestock Expert',
          nameUrdu: 'مویشی پال ماہر',
          icon: PhosphorIcons.cow(),
          categoryName: 'Agriculture & Livestock',
          categoryUrdu: 'زراعت اور مویشی',
          categoryType: ProfessionCategory.agriculture,
        ),
        MasterProfession(
          id: 'tractor_driver',
          name: 'Tractor Driver',
          nameUrdu: 'ٹریکٹر ڈرائیور',
          icon: PhosphorIcons.truck(),
          categoryName: 'Agriculture & Livestock',
          categoryUrdu: 'زراعت اور مویشی',
          categoryType: ProfessionCategory.agriculture,
        ),
        MasterProfession(
          id: 'poultry_expert',
          name: 'Poultry Farm Expert',
          nameUrdu: 'پولٹری فارم ماہر',
          icon: PhosphorIcons.bird(),
          categoryName: 'Agriculture & Livestock',
          categoryUrdu: 'زراعت اور مویشی',
          categoryType: ProfessionCategory.agriculture,
        ),

        // --- بیوٹی اور صحت (Beauty & Wellness) ---
        MasterProfession(
          id: 'barber',
          name: 'Barber / Hair Stylist',
          nameUrdu: 'حجام / نائی',
          icon: PhosphorIcons.scissors(),
          categoryName: 'Beauty & Wellness',
          categoryUrdu: 'بیوٹی اور صحت',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'beautician',
          name: 'Beautician',
          nameUrdu: 'بیوٹیشن (میک اپ)',
          icon: PhosphorIcons.sparkle(),
          categoryName: 'Beauty & Wellness',
          categoryUrdu: 'بیوٹی اور صحت',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'gym_trainer',
          name: 'Gym Trainer',
          nameUrdu: 'جم ٹرینر',
          icon: PhosphorIcons.barbell(),
          categoryName: 'Beauty & Wellness',
          categoryUrdu: 'بیوٹی اور صحت',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'physiotherapist',
          name: 'Physiotherapist',
          nameUrdu: 'فزیو تھراپسٹ',
          icon: PhosphorIcons.handHeart(),
          categoryName: 'Beauty & Wellness',
          categoryUrdu: 'بیوٹی اور صحت',
          categoryType: ProfessionCategory.healthcare,
        ),
        MasterProfession(
          id: 'home_nurse',
          name: 'Home Nurse',
          nameUrdu: 'ہوم نرس',
          icon: PhosphorIcons.firstAidKit(),
          categoryName: 'Beauty & Wellness',
          categoryUrdu: 'بیوٹی اور صحت',
          categoryType: ProfessionCategory.healthcare,
        ),

        // --- کھانا اور پکوان (Food & Hospitality) ---
        MasterProfession(
          id: 'cook',
          name: 'Cook / Chef',
          nameUrdu: 'باورچی / شیف',
          icon: PhosphorIcons.cookingPot(),
          categoryName: 'Food & Hospitality',
          categoryUrdu: 'کھانا اور پکوان',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'baker',
          name: 'Baker / Cake Artist',
          nameUrdu: 'بیکر / کیک ماہر',
          icon: PhosphorIcons.cake(),
          categoryName: 'Food & Hospitality',
          categoryUrdu: 'کھانا اور پکوان',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'catering_service',
          name: 'Catering Service',
          nameUrdu: 'کیٹرنگ سروس',
          icon: PhosphorIcons.forkKnife(),
          categoryName: 'Food & Hospitality',
          categoryUrdu: 'کھانا اور پکوان',
          categoryType: ProfessionCategory.services,
        ),

        // --- ٹرانسپورٹ (Transport & Logistics) ---
        MasterProfession(
          id: 'driver',
          name: 'Car Driver',
          nameUrdu: 'کار ڈرائیور',
          icon: PhosphorIcons.car(),
          categoryName: 'Transport & Logistics',
          categoryUrdu: 'ٹرانسپورٹ اور لاجسٹکس',
          categoryType: ProfessionCategory.transportation,
          defaultUnit: 'سفر',
        ),
        MasterProfession(
          id: 'heavy_driver',
          name: 'Heavy Driver (Truck/Bus)',
          nameUrdu: 'ہیوی ڈرائیور (ٹرک/بس)',
          icon: PhosphorIcons.truck(),
          categoryName: 'Transport & Logistics',
          categoryUrdu: 'ٹرانسپورٹ اور لاجسٹکس',
          categoryType: ProfessionCategory.transportation,
          defaultUnit: 'سفر',
        ),
        MasterProfession(
          id: 'delivery_boy',
          name: 'Delivery Boy',
          nameUrdu: 'ڈیلیوری بائے',
          icon: PhosphorIcons.moped(),
          categoryName: 'Transport & Logistics',
          categoryUrdu: 'ٹرانسپورٹ اور لاجسٹکس',
          categoryType: ProfessionCategory.transportation,
        ),

        // --- تعلیم اور فنون (Education & Arts) ---
        MasterProfession(
          id: 'teacher',
          name: 'Teacher / Tutor',
          nameUrdu: 'ٹیچر / ٹیوٹر',
          icon: PhosphorIcons.bookOpen(),
          categoryName: 'Education & Arts',
          categoryUrdu: 'تعلیم اور فنون',
          categoryType: ProfessionCategory.education,
        ),
        MasterProfession(
          id: 'quran_teacher',
          name: 'Quran Teacher',
          nameUrdu: 'قاری صاحب / ٹیچر',
          icon: PhosphorIcons.mosque(),
          categoryName: 'Education & Arts',
          categoryUrdu: 'تعلیم اور فنون',
          categoryType: ProfessionCategory.education,
        ),
        MasterProfession(
          id: 'photographer',
          name: 'Photographer',
          nameUrdu: 'فوٹوگرافر',
          icon: PhosphorIcons.camera(),
          categoryName: 'Education & Arts',
          categoryUrdu: 'تعلیم اور فنون',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'calligrapher',
          name: 'Calligrapher',
          nameUrdu: 'خوش نویس (خطاط)',
          icon: PhosphorIcons.pencilCircle(),
          categoryName: 'Education & Arts',
          categoryUrdu: 'تعلیم اور فنون',
          categoryType: ProfessionCategory.services,
        ),

        // --- دیگر خدمات (Other Services) ---
        MasterProfession(
          id: 'lawyer',
          name: 'Lawyer',
          nameUrdu: 'وکیل',
          icon: PhosphorIcons.scales(),
          categoryName: 'Other Services',
          categoryUrdu: 'دیگر خدمات',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'accountant',
          name: 'Accountant',
          nameUrdu: 'اکاؤنٹنٹ',
          icon: PhosphorIcons.calculator(),
          categoryName: 'Other Services',
          categoryUrdu: 'دیگر خدمات',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'security',
          name: 'Security Guard',
          nameUrdu: 'سیکیورٹی گارڈ',
          icon: PhosphorIcons.shieldCheck(),
          categoryName: 'Other Services',
          categoryUrdu: 'دیگر خدمات',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'cleaner',
          name: 'Cleaner',
          nameUrdu: 'صفائی کارکن',
          icon: PhosphorIcons.broom(),
          categoryName: 'Other Services',
          categoryUrdu: 'دیگر خدمات',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'translator',
          name: 'Translator',
          nameUrdu: 'مترجم',
          icon: PhosphorIcons.translate(),
          categoryName: 'Other Services',
          categoryUrdu: 'دیگر خدمات',
          categoryType: ProfessionCategory.services,
        ),
        MasterProfession(
          id: 'travel_agent',
          name: 'Travel Agent',
          nameUrdu: 'ٹریول ایجنٹ',
          icon: PhosphorIcons.airplane(),
          categoryName: 'Other Services',
          categoryUrdu: 'دیگر خدمات',
          categoryType: ProfessionCategory.services,
        ),
      ];

  static Map<String, List<String>> get relatedProfessions => {
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

  static List<Map<String, String>> get productionUnits => [
        {'en': 'kg', 'ur': 'کلو'},
        {'en': 'gram', 'ur': 'گرام'},
        {'en': 'ton', 'ur': 'ٹن'},
        {'en': 'man', 'ur': 'من'},
        {'en': 'litre', 'ur': 'لیٹر'},
        {'en': 'dozen', 'ur': 'درجن'},
        {'en': 'piece', 'ur': 'عدد'},
        {'en': 'unit', 'ur': 'یونٹ'},
        {'en': 'project', 'ur': 'پروجیکٹ'},
        {'en': 'trip', 'ur': 'سفر'},
      ];

  static Map<String, IconData> get iconMap {
    final Map<String, IconData> map = {
      'agriculture': PhosphorIcons.tractor(),
      'livestock': PhosphorIcons.cow(),
      'transport': PhosphorIcons.truck(),
      'shop': PhosphorIcons.storefront(),
      'factory': PhosphorIcons.factory(),
      'hammer': PhosphorIcons.hammer(),
      'land': PhosphorIcons.mapPin(),
      'tools': PhosphorIcons.wrench(),
      'food': PhosphorIcons.cookingPot(),
      'tech': PhosphorIcons.cpu(),
      'finance': PhosphorIcons.bank(),
      'cart': PhosphorIcons.shoppingCart(),
    };

    for (final group in professionGroups) {
      map[group.id] = group.icon;
    }

    // Add all individual professions to the icon map
    for (var p in allProfessions) {
      map[p.id] = p.icon;
    }

    return map;
  }

  static List<String> get popularProfessionIds => [
        'electrician',
        'plumber',
        'mason',
        'carpenter',
        'painter',
        'mechanic',
      ];
}
