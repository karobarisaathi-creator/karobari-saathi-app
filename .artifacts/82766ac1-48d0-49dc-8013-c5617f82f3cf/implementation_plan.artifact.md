# مارکیٹ پلیس "عالمی معیار" حتمی اپ گریڈ پلان

اس منصوبے کا مقصد مارکیٹ پلیس کو دنیا کی بہترین ایپس (جیسے Amazon اور Instagram) کے معیار پر لانا ہے۔ اس میں جدید ترین اینیمیشنز، AI ٹولز اور یوزر ریٹینشن فیچرز شامل کیے جائیں گے۔

## یوزر ریویو درکار (User Review Required)

> [!IMPORTANT]
> **AI Category Suggestion:** تصویر اپ لوڈ کرتے ہی ایپ خود بخود کیٹیگری تجویز کرے گی، جس سے اشتہار لگانا بہت آسان ہو جائے گا۔
> **Haptic Feedback:** ایپ استعمال کرتے وقت صارف کو بٹنوں پر ایک "پریمیم" احساس دلانے کے لیے ہلکا وائبریشن فیڈ بیک ملے گا۔

## مجوزہ تبدیلیاں (Proposed Changes)

### 1. یوزر انٹرفیس اور اینیمیشنز (Premium UI/UX)
#### [MODIFY] [marketplace_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/inventory/marketplace_screen.dart)
- **Skeleton Loaders:** پرانے لوڈنگ اسپنر کی جگہ جدید `MarketplaceShimmer` لگانا۔
- **Hero Transitions:** تصاویر کھلتے وقت ہموار اینیمیشن کے لیے `Hero` ویجٹس کا درست استعمال۔

#### [MODIFY] [product_card.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core/widgets/product_card.dart)
- **Haptic Impacts:** لائیک اور ٹپ (Tap) پر `HapticFeedback` کا اضافہ۔

### 2. سمارٹ سیلنگ ٹولز (Smart Seller Tools)
#### [MODIFY] [item_detail_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/inventory/item_detail_screen.dart)
- **Seller Insight Section:** صرف اشتہار کے مالک کے لیے ایک گراف یا شماریاتی کارڈ (Stats Card) دکھانا جو Views اور Shares کے رجحانات ظاہر کرے۔

#### [MODIFY] [add_inventory_item_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/inventory/add_inventory_item_screen.dart)
- **AI Prediction:** تصویر اپ لوڈ ہونے پر `AIVisualService` کو کال کرنا تاکہ کیٹیگری خود بخود منتخب ہو جائے۔

### 3. آٹو میشن اور نوٹیفکیشنز (Retention)
#### [MODIFY] [database_service.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core/services/database_service.dart)
- **Price Drop Logic:** قیمت کم ہونے پر نوٹیفکیشن ٹرگر کرنے کی لاجک بنانا۔

#### [MODIFY] [notification_service.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core/services/notification_service.dart)
- **Price Drop Notifications:** پسندیدہ اشتہار کی قیمت گرنے پر صارف کو الرٹ بھیجنا۔

## تصدیق کا منصوبہ (Verification Plan)

### دستی تصدیق
1. اشتہار لگاتے وقت چیک کرنا کہ کیا AI درست کیٹیگری تجویز کر رہا ہے۔
2. مختلف بٹنوں پر ہپٹک (وائبریشن) چیک کرنا۔
3. لوڈنگ کے دوران شیمر ایفیکٹ کی خوبصورتی دیکھنا۔
4. قیمت کم کر کے چیک کرنا کہ کیا دوسرے صارفین کو نوٹیفکیشن ملتا ہے۔
