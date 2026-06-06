class ArabicReshaper {
  static const int _TATWEEL = 0x0640;

  static final Map<String, List<String>> _ligatureMap = {
    'ا': ['ا', 'ا', 'ﺎ', 'ﺎ'],
    'آ': ['آ', 'آ', 'ﺂ', 'ﺂ'],
    'أ': ['أ', 'أ', 'ﺄ', 'ﺄ'],
    'إ': ['إ', 'إ', 'ﺈ', 'ﺈ'],
    'ب': ['ب', 'ﺑ', 'ﺒ', 'ﺐ'],
    'پ': ['پ', 'ﭘ', 'ﭙ', 'ﭗ'],
    'ت': ['ت', 'ﺗ', 'ﺘ', 'ﺖ'],
    'ٹ': ['ٹ', 'ﭪ', 'ﭧ', 'ﭦ'],
    'ث': ['ث', 'ﺛ', 'ﺜ', 'ﺚ'],
    'ج': ['ج', 'ﺟ', 'ﺠ', 'ﺞ'],
    'چ': ['چ', 'ﭼ', 'ﭽ', 'ﭻ'],
    'ح': ['ح', 'ﺣ', 'ﺤ', 'ﺢ'],
    'خ': ['خ', 'ﺧ', 'ﺨ', 'ﺦ'],
    'د': ['د', 'د', 'ﺪ', 'ﺪ'],
    'ڈ': ['ڈ', 'ڈ', 'ﮉ', 'ﮉ'],
    'ذ': ['ذ', 'ذ', 'ﺬ', 'ﺬ'],
    'ر': ['ر', 'ر', 'ﺮ', 'ﺮ'],
    'ڑ': ['ڑ', 'ڑ', 'ﮍ', 'ﮍ'],
    'ز': ['ز', 'ز', 'ﺰ', 'ﺰ'],
    'ژ': ['ژ', 'ژ', 'ﮋ', 'ﮋ'],
    'س': ['س', 'ﺳ', 'ﺴ', 'ﺲ'],
    'ش': ['ش', 'ﺷ', 'ﺸ', 'ﺶ'],
    'ص': ['ص', 'ﺻ', 'ﺼ', 'ﺺ'],
    'ض': ['ض', 'ﺿ', 'ﻀ', 'ﺾ'],
    'ط': ['ط', 'ﻃ', 'ﻄ', 'ﻂ'],
    'ظ': ['ظ', 'ﻇ', 'ﻈ', 'ﻆ'],
    'ع': ['ع', 'ﻋ', 'ﻌ', 'ﻊ'],
    'غ': ['غ', 'ﻏ', 'ﻐ', 'ﻎ'],
    'ف': ['ف', 'ﻓ', 'ﻔ', 'ﻒ'],
    'ق': ['ق', 'ﻗ', 'ﻘ', 'ﻖ'],
    'ک': ['ک', 'ﮐ', 'ﮑ', 'ﮏ'],
    'ك': ['ك', 'ﻛ', 'ﻜ', 'ﻚ'],
    'گ': ['گ', 'ﮔ', 'ﮕ', 'ﮓ'],
    'ل': ['ل', 'ﻟ', 'ﻠ', 'ﻞ'],
    'م': ['م', 'ﻣ', 'ﻤ', 'ﻢ'],
    'ن': ['ن', 'ﻧ', 'ﻨ', 'ﻦ'],
    'ں': ['ں', 'ں', 'ﮟ', 'ﮟ'],
    'و': ['و', 'و', 'ﻮ', 'ﻮ'],
    'ہ': ['ہ', 'ﮨ', 'ﮩ', 'ﮧ'],
    'ھ': ['ھ', 'ﮭ', 'ﮭ', 'ﮫ'], // Do chashmi hey
    'ء': ['ء', 'ء', 'ء', 'ء'],
    'ی': ['ی', 'ﯾ', 'ﯿ', 'ﯽ'],
    'ے': ['ے', 'ے', 'ﮯ', 'ﮯ'],
    'ة': ['ة', 'ة', 'ﺔ', 'ﺔ'],
    'ؤ': ['ؤ', 'ؤ', 'ﺆ', 'ﺆ'],
    'ئ': ['ئ', 'ﺋ', 'ﺌ', 'ﺊ'],
  };

  static bool _isConnectable(String char) {
    return _ligatureMap.containsKey(char);
  }

  static bool _connectsToLeft(String char) {
    // Characters that can connect to the left (next char)
    // Alif, Dal, Zal, Ra, Za, Waw, etc. do NOT connect to left
    if (!_isConnectable(char)) return false;
    const nonConnectors = ['ا', 'آ', 'أ', 'إ', 'د', 'ڈ', 'ذ', 'ر', 'ڑ', 'ز', 'ژ', 'و', 'ؤ', 'ے', 'ں'];
    return !nonConnectors.contains(char);
  }

  static String convert(String text) {
    if (text.isEmpty) return text;

    List<String> chars = text.split('');
    List<String> reshaped = [];

    for (int i = 0; i < chars.length; i++) {
      String current = chars[i];
      
      // If not an Arabic/Urdu char, keep as is
      if (!_ligatureMap.containsKey(current)) {
        reshaped.add(current);
        continue;
      }

      String? prev = (i > 0) ? chars[i - 1] : null;
      String? next = (i < chars.length - 1) ? chars[i + 1] : null;

      // Check connections
      bool connectPrev = prev != null && _ligatureMap.containsKey(prev) && _connectsToLeft(prev);
      bool connectNext = next != null && _ligatureMap.containsKey(next) && _connectsToLeft(current); // Current must be able to connect left to connect to next

      int formIndex = 0; // 0: Isolated, 1: Initial, 2: Medial, 3: Final

      if (!connectPrev && !connectNext) {
        formIndex = 0; // Isolated
      } else if (!connectPrev && connectNext) {
        formIndex = 1; // Initial
      } else if (connectPrev && connectNext) {
        formIndex = 2; // Medial
      } else if (connectPrev && !connectNext) {
        formIndex = 3; // Final
      }

      List<String> forms = _ligatureMap[current]!;
      if (formIndex < forms.length) {
        reshaped.add(forms[formIndex]);
      } else {
        reshaped.add(current);
      }
    }

    return reshaped.join('');
  }
}
