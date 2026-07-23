# دوہری شناخت کا نظام (Personal vs Seller Profile)

اس منصوبے کا مقصد ایک ہی ایپ کے اندر "ذاتی کھاتہ" اور "عوامی دکان" کو الگ الگ شناخت فراہم کرنا ہے، تاکہ صارف اپنی دکان کا نام اور تصویر اپنی ذاتی معلومات سے مختلف رکھ سکے۔

## یوزر ریویو درکار ہے

> [!IMPORTANT]
> **ڈیٹا بیس کی تبدیلی**: فائر بیس میں صارف کے ڈیٹا کے اندر اب `storeName` اور `storeImage` کی نئی فیلڈز شامل کی جائیں گی۔
> **نام کا انتخاب**: اگر صارف نے اپنی دکان کا نام نہیں رکھا ہوگا، تو ایپ خود بخود اس کا اصلی نام استعمال کرے گی (Fallback)۔

## مجوزہ تبدیلیاں

### 1. سیٹنگز اسکرین میں تبدیلی
#### [ایڈٹ] [settings_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/settings/settings_screen.dart)
- "Update Profile" والے ڈائیلاگ میں "Shop Details" کا ایک نیا ٹیب یا سیکشن شامل کریں۔
- صارف اب اپنا اصلی نام اور دکان کا نام (Store Name) الگ الگ لکھ سکے گا۔

### 2. بازار اور سیلر اسکرین کی اپ ڈیٹ
#### [ایڈٹ] [seller_items_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/inventory/seller_items_screen.dart)
- ہیڈر میں اب `displayName` کے بجائے `storeName` دکھایا جائے گا۔
- پروفائل تصویر کے طور پر `storeImage` استعمال ہوگی۔

#### [ایڈٹ] [marketplace_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/inventory/marketplace_screen.dart)
- پروڈکٹ کارڈز پر بیچنے والے کے نام کی جگہ دکان کا نام نظر آئے گا۔

---

## تصدیق کا منصوبہ

### مینوئل ٹیسٹنگ
1. **سیٹنگز**: اپنا اصلی نام "احمد" اور دکان کا نام "احمد جنرل اسٹور" رکھ کر محفوظ کریں۔
2. **بازار**: چیک کریں کہ آپ کے اشتہار پر "احمد جنرل اسٹور" لکھا آرہا ہے۔
3. **ڈیش بورڈ**: چیک کریں کہ وہاں اب بھی آپ کی ذاتی شناخت (احمد) ہی نظر آرہی ہے۔
