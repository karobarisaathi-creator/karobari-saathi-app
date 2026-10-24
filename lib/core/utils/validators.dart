class Validators {
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'فون نمبر درج کریں';
    }
    
    final phoneRegex = RegExp(r'^(\+92|92|0)?3\d{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'درست فون نمبر درج کریں';
    }
    
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'نام درج کریں';
    }
    
    if (value.length < 2) {
      return 'نام کم از کم 2 حروف کا ہونا چاہیے';
    }
    
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم درج کریں';
    }
    
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'درست رقم درج کریں';
    }
    
    if (amount <= 0) {
      return 'رقم صفر سے زیادہ ہونی چاہیے';
    }
    
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Email is optional
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'درست ای میل درج کریں';
    }
    
    return null;
  }
}