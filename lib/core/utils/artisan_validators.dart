/// کاریگر کے ڈیٹا کی تصدیق (Validation) کے لیے یوٹیلٹی کلاس
class ArtisanValidators {
  /// فون نمبر کی تصدیق کرتا ہے (7 سے 15 ہندسے)
  static bool isValidPhone(String phone) {
    final regex = RegExp(r'^[+]?[0-9]{7,15}$');
    return regex.hasMatch(phone);
  }

  /// کام کی تفصیل کی تصدیق کرتا ہے (10 سے 500 حروف)
  static bool isValidDescription(String desc) {
    return desc.isNotEmpty && desc.length >= 10 && desc.length <= 500;
  }

  /// بجٹ کی تصدیق کرتا ہے (0 سے زیادہ اور ایک حد کے اندر)
  static bool isValidBudget(double? budget) {
    return budget != null && budget > 0 && budget < 10000000;
  }

  /// تجربے کے سالوں کی تصدیق کرتا ہے (0 سے 70 سال)
  static bool isValidExperience(int years) {
    return years >= 0 && years <= 70;
  }

  /// لوکیشن (عرض بلد اور طول بلد) کی تصدیق کرتا ہے
  static bool isValidLocation(double? lat, double? long) {
    return lat != null && long != null && 
           lat >= -90 && lat <= 90 && 
           long >= -180 && long <= 180;
  }

  /// مختلف فیلڈز کے لیے اردو یا انگریزی میں غلطی کا پیغام فراہم کرتا ہے
  static String getErrorMessage(String fieldName, {bool isUrdu = true}) {
    if (isUrdu) {
      switch (fieldName) {
        case 'phone':
          return 'فون نمبر غلط ہے (مثلاً: 03001234567)';
        case 'description':
          return 'تفصیل کم از کم 10 اور زیادہ سے زیادہ 500 حروف میں ہونی چاہیے';
        case 'budget':
          return 'بجٹ 0 سے زیادہ ہونا چاہیے';
        case 'experience':
          return 'تجربہ 0 سے 70 سال کے درمیان ہونا چاہیے';
        default:
          return 'درج کردہ معلومات درست نہیں ہیں';
      }
    } else {
      switch (fieldName) {
        case 'phone':
          return 'Invalid phone number';
        case 'description':
          return 'Description must be between 10 and 500 characters';
        case 'budget':
          return 'Budget must be greater than 0';
        case 'experience':
          return 'Experience must be between 0 and 70 years';
        default:
          return 'Invalid data';
      }
    }
  }
}
