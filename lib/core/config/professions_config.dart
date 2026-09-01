import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/profession_model.dart';

class MasterProfession {
  final String id;
  final String name;
  final IconData icon;
  final String categoryName;
  final String categoryUrdu;
  final ProfessionCategory categoryType;
  final String defaultUnit;

  const MasterProfession({
    required this.id,
    required this.name,
    required this.icon,
    required this.categoryName,
    required this.categoryUrdu,
    required this.categoryType,
    this.defaultUnit = 'unit',
  });
}

class ProfessionsConfig {
  static List<MasterProfession> get allProfessions => [
    // --- تعمیرات اور ہارڈویئر (Construction & Hardware) ---
    MasterProfession(
      id: 'mason',
      name: 'راج / مستری',
      icon: PhosphorIcons.wall(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
      defaultUnit: 'پروجیکٹ',
    ),
    MasterProfession(
      id: 'plumber',
      name: 'پلمبر',
      icon: PhosphorIcons.wrench(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),
    MasterProfession(
      id: 'electrician',
      name: 'الیکٹریشن',
      icon: PhosphorIcons.lightning(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),
    MasterProfession(
      id: 'carpenter',
      name: 'ترکھان (لکڑی کا کام)',
      icon: PhosphorIcons.hammer(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),
    MasterProfession(
      id: 'painter',
      name: 'پینٹر',
      icon: PhosphorIcons.paintBrushBroad(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),
    MasterProfession(
      id: 'welder',
      name: 'ویلڈر',
      icon: PhosphorIcons.fire(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),
    MasterProfession(
      id: 'tile_fixer',
      name: 'ٹائل فکسر',
      icon: PhosphorIcons.gridFour(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),
    MasterProfession(
      id: 'plaster',
      name: 'پلاسٹر ماہر',
      icon: PhosphorIcons.paintRoller(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),
    MasterProfession(
      id: 'steel_fixer',
      name: 'سٹیل فکسر',
      icon: PhosphorIcons.stairs(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),
    MasterProfession(
      id: 'aluminum_worker',
      name: 'ایلومینیم کا کام',
      icon: PhosphorIcons.frameCorners(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),
    MasterProfession(
      id: 'glass_worker',
      name: 'شیشے کا کام',
      icon: PhosphorIcons.selectionAll(),
      categoryName: 'Construction & Hardware',
      categoryUrdu: 'تعمیرات اور ہارڈویئر',
      categoryType: ProfessionCategory.construction,
    ),

    // --- آئی ٹی اور سافٹ ویئر (IT & Software) ---
    MasterProfession(
      id: 'software_dev',
      name: 'سوفٹ ویئر ڈویلپر',
      icon: PhosphorIcons.code(),
      categoryName: 'IT & Software',
      categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
      categoryType: ProfessionCategory.technology,
      defaultUnit: 'پروجیکٹ',
    ),
    MasterProfession(
      id: 'web_designer',
      name: 'ویب ڈیزائنر',
      icon: PhosphorIcons.browser(),
      categoryName: 'IT & Software',
      categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
      categoryType: ProfessionCategory.technology,
    ),
    MasterProfession(
      id: 'graphic_designer',
      name: 'گرافک ڈیزائنر',
      icon: PhosphorIcons.palette(),
      categoryName: 'IT & Software',
      categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
      categoryType: ProfessionCategory.technology,
    ),
    MasterProfession(
      id: 'digital_marketer',
      name: 'ڈیجیٹل مارکیٹنگ',
      icon: PhosphorIcons.megaphone(),
      categoryName: 'IT & Software',
      categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
      categoryType: ProfessionCategory.technology,
    ),
    MasterProfession(
      id: 'video_editor',
      name: 'ویڈیو ایڈیٹر',
      icon: PhosphorIcons.videoCamera(),
      categoryName: 'IT & Software',
      categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
      categoryType: ProfessionCategory.technology,
    ),
    MasterProfession(
      id: 'data_entry',
      name: 'ڈیٹا اینٹری آپریٹر',
      icon: PhosphorIcons.keyboard(),
      categoryName: 'IT & Software',
      categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
      categoryType: ProfessionCategory.technology,
    ),
    MasterProfession(
      id: 'seo_expert',
      name: 'SEO ایکسپرٹ',
      icon: PhosphorIcons.magnifyingGlassPlus(),
      categoryName: 'IT & Software',
      categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
      categoryType: ProfessionCategory.technology,
    ),
    MasterProfession(
      id: 'mobile_app_developer',
      name: 'موبائل ایپ ڈویلپر',
      icon: PhosphorIcons.deviceMobile(),
      categoryName: 'IT & Software',
      categoryUrdu: 'آئی ٹی اور سافٹ ویئر',
      categoryType: ProfessionCategory.technology,
    ),

    // --- مرمت اور مکینک (Repair & Mechanics) ---
    MasterProfession(
      id: 'mobile_repair',
      name: 'موبائل ریپیئرنگ',
      icon: PhosphorIcons.deviceMobile(),
      categoryName: 'Repair & Mechanics',
      categoryUrdu: 'مرمت اور مکینک',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'laptop_repair',
      name: 'کمپیوٹر / لیپ ٹاپ ریپیئر',
      icon: PhosphorIcons.laptop(),
      categoryName: 'Repair & Mechanics',
      categoryUrdu: 'مرمت اور مکینک',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'ac_technician',
      name: 'AC ٹیکنیشن',
      icon: PhosphorIcons.snowflake(),
      categoryName: 'Repair & Mechanics',
      categoryUrdu: 'مرمت اور مکینک',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'solar_installer',
      name: 'سولر انسٹالر',
      icon: PhosphorIcons.sun(),
      categoryName: 'Repair & Mechanics',
      categoryUrdu: 'مرمت اور مکینک',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'mechanic',
      name: 'گاڑیوں کا مکینک',
      icon: PhosphorIcons.engine(),
      categoryName: 'Repair & Mechanics',
      categoryUrdu: 'مرمت اور مکینک',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'bike_mechanic',
      name: 'بائیک مکینک',
      icon: PhosphorIcons.bicycle(),
      categoryName: 'Repair & Mechanics',
      categoryUrdu: 'مرمت اور مکینک',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'cctv_installer',
      name: 'کیمرہ انسٹالر (CCTV)',
      icon: PhosphorIcons.cameraPlus(),
      categoryName: 'Repair & Mechanics',
      categoryUrdu: 'مرمت اور مکینک',
      categoryType: ProfessionCategory.services,
    ),

    // --- زراعت اور مویشی (Agriculture & Livestock) ---
    MasterProfession(
      id: 'agri_expert',
      name: 'ماہرِ زراعت',
      icon: PhosphorIcons.plant(),
      categoryName: 'Agriculture & Livestock',
      categoryUrdu: 'زراعت اور مویشی',
      categoryType: ProfessionCategory.agriculture,
      defaultUnit: 'کلو',
    ),
    MasterProfession(
      id: 'gardener',
      name: 'مالی',
      icon: PhosphorIcons.leaf(),
      categoryName: 'Agriculture & Livestock',
      categoryUrdu: 'زراعت اور مویشی',
      categoryType: ProfessionCategory.agriculture,
    ),
    MasterProfession(
      id: 'livestock_expert',
      name: 'مویشی پال ماہر',
      icon: PhosphorIcons.cow(),
      categoryName: 'Agriculture & Livestock',
      categoryUrdu: 'زراعت اور مویشی',
      categoryType: ProfessionCategory.agriculture,
    ),
    MasterProfession(
      id: 'tractor_driver',
      name: 'ٹریکٹر ڈرائیور',
      icon: PhosphorIcons.truck(),
      categoryName: 'Agriculture & Livestock',
      categoryUrdu: 'زراعت اور مویشی',
      categoryType: ProfessionCategory.agriculture,
    ),
    MasterProfession(
      id: 'poultry_expert',
      name: 'پولٹری فارم ماہر',
      icon: PhosphorIcons.bird(),
      categoryName: 'Agriculture & Livestock',
      categoryUrdu: 'زراعت اور مویشی',
      categoryType: ProfessionCategory.agriculture,
    ),

    // --- بیوٹی اور صحت (Beauty & Wellness) ---
    MasterProfession(
      id: 'barber',
      name: 'حجام / نائی',
      icon: PhosphorIcons.scissors(),
      categoryName: 'Beauty & Wellness',
      categoryUrdu: 'بیوٹی اور صحت',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'beautician',
      name: 'بیوٹیشن (میک اپ)',
      icon: PhosphorIcons.sparkle(),
      categoryName: 'Beauty & Wellness',
      categoryUrdu: 'بیوٹی اور صحت',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'gym_trainer',
      name: 'جم ٹرینر',
      icon: PhosphorIcons.barbell(),
      categoryName: 'Beauty & Wellness',
      categoryUrdu: 'بیوٹی اور صحت',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'physiotherapist',
      name: 'فزیو تھراپسٹ',
      icon: PhosphorIcons.handHeart(),
      categoryName: 'Beauty & Wellness',
      categoryUrdu: 'بیوٹی اور صحت',
      categoryType: ProfessionCategory.healthcare,
    ),
    MasterProfession(
      id: 'home_nurse',
      name: 'ہوم نرس',
      icon: PhosphorIcons.firstAidKit(),
      categoryName: 'Beauty & Wellness',
      categoryUrdu: 'بیوٹی اور صحت',
      categoryType: ProfessionCategory.healthcare,
    ),

    // --- کھانا اور پکوان (Food & Hospitality) ---
    MasterProfession(
      id: 'cook',
      name: 'باورچی / شیف',
      icon: PhosphorIcons.cookingPot(),
      categoryName: 'Food & Hospitality',
      categoryUrdu: 'کھانا اور پکوان',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'baker',
      name: 'بیکر / کیک ماہر',
      icon: PhosphorIcons.cake(),
      categoryName: 'Food & Hospitality',
      categoryUrdu: 'کھانا اور پکوان',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'catering_service',
      name: 'کیٹرنگ سروس',
      icon: PhosphorIcons.forkKnife(),
      categoryName: 'Food & Hospitality',
      categoryUrdu: 'کھانا اور پکوان',
      categoryType: ProfessionCategory.services,
    ),

    // --- ٹرانسپورٹ (Transport & Logistics) ---
    MasterProfession(
      id: 'driver',
      name: 'کار ڈرائیور',
      icon: PhosphorIcons.car(),
      categoryName: 'Transport & Logistics',
      categoryUrdu: 'ٹرانسپورٹ اور لاجسٹکس',
      categoryType: ProfessionCategory.transportation,
      defaultUnit: 'سفر',
    ),
    MasterProfession(
      id: 'heavy_driver',
      name: 'ہیوی ڈرائیور (ٹرک/بس)',
      icon: PhosphorIcons.truck(),
      categoryName: 'Transport & Logistics',
      categoryUrdu: 'ٹرانسپورٹ اور لاجسٹکس',
      categoryType: ProfessionCategory.transportation,
      defaultUnit: 'سفر',
    ),
    MasterProfession(
      id: 'delivery_boy',
      name: 'ڈیلیوری بائے',
      icon: PhosphorIcons.moped(),
      categoryName: 'Transport & Logistics',
      categoryUrdu: 'ٹرانسپورٹ اور لاجسٹکس',
      categoryType: ProfessionCategory.transportation,
    ),

    // --- تعلیم اور فنون (Education & Arts) ---
    MasterProfession(
      id: 'teacher',
      name: 'ٹیچر / ٹیوٹر',
      icon: PhosphorIcons.bookOpen(),
      categoryName: 'Education & Arts',
      categoryUrdu: 'تعلیم اور فنون',
      categoryType: ProfessionCategory.education,
    ),
    MasterProfession(
      id: 'quran_teacher',
      name: 'قاری صاحب / ٹیچر',
      icon: PhosphorIcons.mosque(),
      categoryName: 'Education & Arts',
      categoryUrdu: 'تعلیم اور فنون',
      categoryType: ProfessionCategory.education,
    ),
    MasterProfession(
      id: 'photographer',
      name: 'فوٹوگرافر',
      icon: PhosphorIcons.camera(),
      categoryName: 'Education & Arts',
      categoryUrdu: 'تعلیم اور فنون',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'calligrapher',
      name: 'خوش نویس (خطاط)',
      icon: PhosphorIcons.pencilCircle(),
      categoryName: 'Education & Arts',
      categoryUrdu: 'تعلیم اور فنون',
      categoryType: ProfessionCategory.services,
    ),

    // --- دیگر خدمات (Other Services) ---
    MasterProfession(
      id: 'lawyer',
      name: 'وکیل',
      icon: PhosphorIcons.scales(),
      categoryName: 'Other Services',
      categoryUrdu: 'دیگر خدمات',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'accountant',
      name: 'اکاؤنٹنٹ',
      icon: PhosphorIcons.calculator(),
      categoryName: 'Other Services',
      categoryUrdu: 'دیگر خدمات',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'security',
      name: 'سیکیورٹی گارڈ',
      icon: PhosphorIcons.shieldCheck(),
      categoryName: 'Other Services',
      categoryUrdu: 'دیگر خدمات',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'cleaner',
      name: 'صفائی کارکن',
      icon: PhosphorIcons.broom(),
      categoryName: 'Other Services',
      categoryUrdu: 'دیگر خدمات',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'translator',
      name: 'مترجم',
      icon: PhosphorIcons.translate(),
      categoryName: 'Other Services',
      categoryUrdu: 'دیگر خدمات',
      categoryType: ProfessionCategory.services,
    ),
    MasterProfession(
      id: 'travel_agent',
      name: 'ٹریول ایجنٹ',
      icon: PhosphorIcons.airplane(),
      categoryName: 'Other Services',
      categoryUrdu: 'دیگر خدمات',
      categoryType: ProfessionCategory.services,
    ),
  ];

  static Map<String, List<String>> get relatedProfessions => {
    'electrician': ['plumber', 'carpenter', 'solar_installer', 'ac_technician'],
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
