// Professional AI Prompts Configuration for Karobari Saathi App
// Version: 4.0.0 (Ultimate Version - Detailed & Synced)
// Last Updated: 2026-01-26

class AIPrompts {
  
  // ==================== SYSTEM PROMPTS ====================
  
  static const String systemPrompt = '''
You are **Karobari Saathi AI**, an expert business consultant and product analyst for Pakistan's leading marketplace.

## YOUR IDENTITY:
- Role: Professional product analyst, price auditor, and deal validator.
- Market Focus: Pakistan (All cities: Karachi, Lahore, Islamabad, Faisalabad, etc.)
- Language: Dual-language (Respond in the same language user uses: Urdu or English).

## YOUR CORE VALUES:
1. **Accuracy** - Never guess; be honest about data limitations.
2. **Local Context** - Prices in PKR, local market trends (e.g., PTA status, engine power, area in Marla/Kanal).
3. **Actionable Advice** - Tell the user *why* a deal is good or bad.
4. **Brevity** - Clean, professional, and useful responses without fluff.

## CRITICAL RULES (ABSOLUTE):
1. Return ONLY valid JSON. No markdown, no backticks, no explanations.
2. Prices must be PKR as plain numbers (e.g., "85000").
3. Confidence score: 0-100 (integer).
4. Category MUST be selected from the allowed list below.
5. For Mobiles: Always mention PTA status in specs or advice if known.
6. For Used items: Note "Used/Pre-owned" clearly.

## OUTPUT FORMAT:
{
  "name": "Full product name with key specs",
  "brand": "Brand name or 'Unknown'",
  "price": "numeric_string",
  "category": "Selected from the allowed list",
  "specs": "Category-specific technical details (Format: Key: Value, Key: Value)",
  "confidence": "0-100",
  "pros": "point1, point2, point3",
  "cons": "point1, point2, point3",
  "advice": "Short professional buying recommendation (max 20 words)"
}
''';

  // ==================== CATEGORY-WISE SPECIFICATIONS ====================
  
  static const Map<String, String> categorySpecsGuidelines = {
    "Mobiles": "RAM: XGB, Storage: XGB, Processor: Model, PTA Status: Approved/Patch/CPID, Battery: mAh",
    "Electronics": "Model: Name, Power: Watt/Amp, Warranty: Type/Period, Condition: New/Used",
    "Vehicles": "Engine: Xcc, Mileage: Xkm, Year: XXXX, Transmission: Auto/Manual, Registration: City",
    "Real Estate": "Size: Marla/Kanal, Type: Plot/House, Bedrooms: X, Location: Specific Area",
    "Agriculture": "Crop/Seed: Name, Variety: Type, Yield: Expected, Season: Name",
    "Livestock": "Breed: Name, Age: Years/Months, Weight: kg, Milk: Liters/Day, Purpose: Qurbani/Dairy",
    "Clothing": "Size: S/M/L/XL, Fabric: Material, Type: Season/Style, Gender: Men/Women/Unisex",
    "Furniture": "Material: Type of wood/metal, Dimensions: Size, Set: Items included, Polish: Type",
    "Food": "Weight: kg/g, Expiry: Date, Origin: Brand/Farm, Type: Fresh/Packed",
    "Medical": "Formula: Generic name, Strength: mg/ml, Pack: Size, Expiry: Date",
    "Stationery": "Brand: Name, Pack: Quantity, Size: Dimension, Type: Item type",
    "Hardware": "Material: Steel/Plastic/Iron, Gauge: Size, Brand: Name, Weight: kg",
    "Construction": "Grade: X, Type: Item type, Brand: Name, Quantity: Unit",
    "Services": "Service: Name, Experience: Years, Location: Area, Availability: Hours",
    "Transport": "Vehicle: Type, Route: From-To, Capacity: Tons/Seats, Type: Goods/Passenger",
    "Raw Material": "Material: Name, Grade: X, Origin: Source, Weight: kg/ton",
    "Assets": "Asset: Type, Condition: X, Age: Years, Value: estimated",
    "General": "Provide 2-3 most important specifications",
    "Other": "Provide 2-3 most important specifications"
  };

  // ==================== CATEGORIES (MATCHED WITH APP_FILTER_CHIP) ====================
  
  static const List<String> productCategories = [
    "General", "Mobiles", "Electronics", "Vehicles", "Real Estate", 
    "Agriculture", "Livestock", "Clothing", "Furniture", "Food", 
    "Medical", "Stationery", "Hardware", "Construction", "Services", 
    "Transport", "Raw Material", "Assets", "Other"
  ];

  // ==================== PRICE GUIDELINES (PKR) ====================
  
  static const Map<String, Map<String, int>> priceGuidelines = {
    "Mobiles": {"min": 5000, "max": 600000, "average": 85000},
    "Electronics": {"min": 1000, "max": 500000, "average": 60000},
    "Vehicles": {"min": 150000, "max": 25000000, "average": 3500000},
    "Real Estate": {"min": 1500000, "max": 100000000, "average": 15000000},
    "Agriculture": {"min": 2000, "max": 1000000, "average": 50000},
    "Livestock": {"min": 30000, "max": 2000000, "average": 150000},
    "Clothing": {"min": 300, "max": 80000, "average": 4500},
    "Furniture": {"min": 5000, "max": 500000, "average": 45000},
    "Food": {"min": 50, "max": 15000, "average": 800},
    "Medical": {"min": 20, "max": 20000, "average": 400},
    "Stationery": {"min": 20, "max": 10000, "average": 500},
    "Hardware": {"min": 50, "max": 100000, "average": 2000},
    "Construction": {"min": 100, "max": 500000, "average": 10000},
    "Services": {"min": 500, "max": 200000, "average": 5000},
    "Transport": {"min": 1000, "max": 500000, "average": 20000},
    "Raw Material": {"min": 100, "max": 1000000, "average": 50000},
    "Assets": {"min": 5000, "max": 5000000, "average": 100000},
    "General": {"min": 100, "max": 1000000, "average": 10000},
    "Other": {"min": 100, "max": 1000000, "average": 10000},
  };

  // ==================== CORE PROMPTS ====================
  
  static const String imageAnalysisPrompt = '''
Identify the product in the image. Estimate its current market value in Pakistan.

## STEPS:
1. Detect brand/model/condition from visual cues.
2. Calculate price based on local Pakistani market trends (Hafeez Center, Daraz, OLX).
3. Extract category-specific specs using the provided guidelines.
4. If image is blurry or unclear, set confidence < 50.

## SPEC GUIDELINES:
[SPEC_GUIDELINES]
''';

  static const String textSearchPrompt = '''
Search for the most accurate current price and specs for the following query in Pakistan.

## SEARCH STRATEGY:
1. Research official prices vs local market prices (Lahore/Karachi/Islamabad).
2. Check for latest model variations and specs.
3. Provide 3 Pros and 3 Cons (comma separated).
4. Extract specs according to category guidelines.

## CONFIDENCE GUIDELINES:
- 90-100%: Verified official/recent data.
- 70-89%: Multiple sources agree.
- 50-69%: Some uncertainty or single source.
- < 50%: Estimated or limited information.

## SPEC GUIDELINES:
[SPEC_GUIDELINES]
''';

  static const String detailedSearchPrompt = '''
You are an expert product researcher for Karobari Saathi marketplace.

## RESEARCH PROCESS:
1. Find official specifications and Pakistan market price.
2. Compare with similar products and identify best alternatives.
3. Note seasonal price variations (Eid, Ramadan, etc.).

## CATEGORY-SPECIFIC SPEC EXAMPLES:
- **Mobiles:** "RAM: 8GB, Storage: 256GB, Processor: Snapdragon 8, PTA: Approved"
- **Vehicles:** "Engine: 1800cc, Mileage: 15km/L, Year: 2024, Transmission: Automatic"
- **Real Estate:** "Size: 5 Marla, Bedrooms: 3, Location: DHA Lahore"
- **Livestock:** "Breed: Holstein, Age: 3 years, Milk: 25L/day, Weight: 500kg"

## OUTPUT:
Return ONLY valid JSON following the master system prompt format.
''';

  static const String priceComparisonPrompt = '''
Compare prices from local marketplaces (Daraz, PriceOye, OLX) and provide the best deal.

## ANALYSIS:
- Identify lowest price and check if reasonable (not a scam).
- Note price differences by city/location.
- Consider shipping costs for online deals.

## OUTPUT FORMAT:
{
  "best_deal": {"source": "Name", "price": "numeric", "location": "City/Online"},
  "alternatives": [{"source": "Name", "price": "numeric", "note": "reason"}],
  "savings": "amount",
  "advice": "Buying recommendation"
}
''';

  static const String dealValidationPrompt = '''
Validate if this deal is legitimate and a "Good Buy" for a Pakistani user.

## RED FLAGS:
- Price too low (< 50% of market average).
- Counterfeit/fake brands or missing PTA for mobiles.
- No warranty or suspicious discounts (> 70%).

## LEGITIMATE INDICATORS:
- Price within 20% of market average.
- Clear brand/model and local warranty.

## OUTPUT:
{
  "is_legitimate": boolean,
  "confidence": "0-100",
  "risk_factors": ["list"],
  "fair_price": "numeric",
  "advice": "actionable tip"
}
''';

  static const String recommendationPrompt = '''
Recommend 3 similar products available in Pakistan within a similar budget range.

## CRITERIA:
1. Similar price range (±20%) and similar/better specs.
2. Popular and available in the Pakistan market.

## OUTPUT FORMAT:
{
  "recommendations": [{"name": "Product", "price": "numeric", "reason": "Why", "better_than_original": bool}],
  "best_overall": "Which is best and why",
  "budget_option": "Affordable alternative"
}
''';

  // ==================== HELPER METHODS ====================
  
  static String _getAllSpecsText() {
    StringBuffer buffer = StringBuffer();
    for (var entry in categorySpecsGuidelines.entries) {
      buffer.writeln("- **${entry.key}**: ${entry.value}");
    }
    return buffer.toString();
  }
  
  static String getSpecsGuidelinesForCategory(String category) {
    return categorySpecsGuidelines[category] ?? categorySpecsGuidelines["Other"]!;
  }
  
  static Map<String, int>? getPriceRange(String category) {
    return priceGuidelines[category];
  }
  
  static bool isPriceReasonable(String category, double price) {
    final range = priceGuidelines[category];
    if (range == null) return true;
    return price >= range['min']! && price <= range['max']!;
  }
  
  static String getConfidenceDescription(int confidence) {
    if (confidence >= 90) return "Very High - Highly confident";
    if (confidence >= 70) return "High - Reasonably confident";
    if (confidence >= 50) return "Medium - Some uncertainty";
    return "Low - Please verify independently";
  }
  
  static String getCategoryEmoji(String category) {
    switch (category) {
      case "General": return "📦";
      case "Mobiles": return "📱";
      case "Electronics": return "💻";
      case "Vehicles": return "🚗";
      case "Real Estate": return "🏠";
      case "Agriculture": return "🌾";
      case "Livestock": return "🐄";
      case "Clothing": return "👕";
      case "Furniture": return "🪑";
      case "Food": return "🍔";
      case "Medical": return "💊";
      case "Stationery": return "✏️";
      case "Hardware": return "🔧";
      case "Construction": return "🏗️";
      case "Services": return "🤝";
      case "Transport": return "🚛";
      case "Raw Material": return "🏭";
      case "Assets": return "💰";
      default: return "📦";
    }
  }
  
  static String buildPrompt(String basePrompt, {String? query, String? context}) {
    String specs = _getAllSpecsText();
    String finalBase = basePrompt.replaceAll("[SPEC_GUIDELINES]", specs);
    
    StringBuffer fullPrompt = StringBuffer();
    fullPrompt.writeln(systemPrompt);
    fullPrompt.writeln("\n## TASK:\n$finalBase");
    
    if (query != null && query.isNotEmpty) fullPrompt.writeln("\n## USER INPUT:\n$query");
    if (context != null && context.isNotEmpty) fullPrompt.writeln("\n## CONTEXT:\n$context");
    
    fullPrompt.writeln("\n## FINAL REMINDER (CRITICAL):");
    fullPrompt.writeln("The response will be parsed directly by jsonDecode().");
    fullPrompt.writeln("Return ONLY a valid JSON object. No markdown, no backticks, no extra text before or after.");
    
    return fullPrompt.toString();
  }
}

// ==================== EXTENSION ====================

extension AIPromptsExtension on AIPrompts {
  static String get system => AIPrompts.systemPrompt;
  static String get imageAnalysis => AIPrompts.imageAnalysisPrompt;
  static String get textSearch => AIPrompts.textSearchPrompt;
  static String get detailedSearch => AIPrompts.detailedSearchPrompt;
  static String get priceComparison => AIPrompts.priceComparisonPrompt;
  static String get dealValidation => AIPrompts.dealValidationPrompt;
  static String get recommendations => AIPrompts.recommendationPrompt;
  
  static List<String> get categories => AIPrompts.productCategories;
  static Map<String, String> get specsGuidelines => AIPrompts.categorySpecsGuidelines;
}
