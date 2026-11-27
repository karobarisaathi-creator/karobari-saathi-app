# پرائیویسی پالیسی — کاروباری ساتھی (Account App)
**نفاذ کی تاریخ / Effective Date: 27 نومبر 2026 / November 27, 2026**

یہ پالیسی ایپ کے موجودہ کوڈ اور اس میں نظر آنے والے رویے کی بنیاد پر لکھی گئی ہے۔ جن امور کی عملی یا قانونی تصدیق نہیں ہو سکی، انہیں واضح طور پر نشان زد کیا گیا ہے۔

This policy is based on the app’s current code and observable behavior. Items that could not be verified operationally or legally are marked for confirmation.

## ۱. تعارف
کاروباری ساتھی ایک موبائل ایپ ہے جو کاروباری کھاتے، لین دین، اسٹاک، معاہدے اور مزدوروں کی حاضری/اجرت کے ریکارڈ سنبھالنے میں مدد دیتی ہے۔

Karobari Saathi is a mobile app for managing business accounts, transactions, inventory, contracts, and worker attendance/payroll records.

## ۲. کون سا ڈیٹا استعمال ہوتا ہے
- **اکاؤنٹ اور پروفائل:** فون نمبر، SMS تصدیق، نام، ای میل (اگر درج ہو)، دکان کا نام، پیشہ، تصویر اور کاروباری پتہ۔
- **کاروباری ریکارڈ:** آپ کے درج کردہ گاہکوں، سپلائرز اور مزدوروں کے نام، فون نمبر اور پتے؛ کھاتے، لین دین کی رقم/تاریخ/نوٹس، اسٹاک، معاہدے، حاضری/اجرت اور متعلقہ تصاویر۔
- **رابطے:** جب آپ رابطہ منتخب کرنے کی سہولت استعمال کریں تو منتخب رابطے کا نام اور فون نمبر پڑھا جا سکتا ہے۔
- **ایپ اور اکاؤنٹ ریکارڈ:** سنک/بیک اپ کی معلومات، ترتیبات، اور ایپ استعمال کرتے وقت بننے والے متعلقہ ریکارڈ۔
- **پرانا مقام کا ڈیٹا:** موجودہ ورژن GPS یا نقشہ استعمال نہیں کرتا۔ پہلے ورژن سے محفوظ شدہ کوآرڈینیٹس پروفائل دوبارہ محفوظ کرنے یا اکاؤنٹ حذف ہونے تک کلاؤڈ میں رہ سکتے ہیں۔

### English
- **Account and profile:** Phone number, SMS verification, name, email (if entered), shop name, profession, photo, and business address.
- **Business records:** Names, phone numbers and addresses of customers, suppliers and workers that you enter; accounts, transaction amounts/dates/notes, inventory, contracts, attendance/payroll, and related images.
- **Contacts:** When you choose to use contact selection, the selected contact’s name and phone number may be read.
- **App and account records:** Sync/backup information, settings, and related records generated while using the app.
- **Legacy location data:** The current version does not use GPS or maps. Coordinates saved by an earlier version may remain in cloud storage until you save your profile again or your account is deleted.

## ۳. ڈیٹا کیسے اور کیوں استعمال ہوتا ہے
فون نمبر اور SMS تصدیق اکاؤنٹ میں داخلے کے لیے استعمال ہوتے ہیں۔ ایپ آپ کے کاروباری ریکارڈ محفوظ اور منظم کرتی ہے۔ ایپ کا سنک فنکشن چلنے پر اکاؤنٹس، لین دین اور کچھ دوسرے ریکارڈ Firebase کے ساتھ سنک ہو سکتے ہیں۔ بیک اپ آپ کی درخواست پر بنایا جاتا ہے۔ پروفائل/دکان کی معلومات دکھائی جاتی ہیں، اور مزدور کا فون نمبر کسی ایپ اکاؤنٹ سے ملنے پر مخصوص اجرت کا اندراج اس اکاؤنٹ میں نقل اور اس کی اطلاع بھیجی جا سکتی ہے۔

**سنک کی درست شرائط اور وقت:** [تصدیق درکار: ایپ میں سنک کن حالات میں اور کتنی بار خودکار طور پر چلتا ہے۔]

### English
Your phone number and SMS verification are used for account access. The app stores and manages your business records. When the app’s sync function runs, accounts, transactions and some other records may sync with Firebase. A backup is created at your request. Profile/shop information is displayed, and if a worker’s phone number matches an app account, a specific wage entry may be copied to that account and a notification may be sent.

**Exact sync conditions and timing:** [Verification required: confirm when and how often the app syncs automatically.]

## ۴. فون، کلاؤڈ اور بیک اپ
کاروباری ریکارڈ کا بڑا حصہ فون کے مقامی ڈیٹا بیس میں رکھا جاتا ہے۔ ایپ بعض ترتیبات کے لیے SharedPreferences اور ایپ لاک کی حساس معلومات کے لیے ڈیوائس کا محفوظ اسٹوریج بھی استعمال کرتی ہے۔ سنک ہونے والا ڈیٹا اور آپ کے بنائے ہوئے بیک اپ Firebase Authentication، Cloud Firestore اور Firebase Storage میں محفوظ ہو سکتے ہیں۔ بیک اپ میں کھاتے، لین دین، اسٹاک، معاہدے، مزدوروں کی اجرت اور دیگر متعلقہ ریکارڈ شامل ہو سکتے ہیں۔ بیک اپ بنانے کے لیے پروفائل میں ای میل درج ہونا ضروری ہے۔

**کلاؤڈ بیک اپ کی مدت، سرور کا خطہ، اور Firebase Console کی ترتیبات:** [تصدیق درکار]

### English
Most business records are stored in the device’s local database. The app also uses SharedPreferences for some settings and the device’s secure storage for sensitive app-lock information. Synced data and backups you create may be stored in Firebase Authentication, Cloud Firestore and Firebase Storage. A backup may include accounts, transactions, inventory, contracts, worker payroll and related records. An email address in your profile is required to create a backup.

**Cloud-backup retention, server region, and Firebase Console configuration:** [Verification required]

## ۵. کون ڈیٹا دیکھ سکتا ہے یا وصول کر سکتا ہے
- آپ کے نجی کھاتے اور لین دین عموماً آپ کے اکاؤنٹ تک محدود ہیں۔
- مزدور کا فون نمبر کسی ایپ اکاؤنٹ سے ملنے پر، مخصوص اجرت کا نقل شدہ اندراج متعلقہ مزدور کے اکاؤنٹ میں جا سکتا ہے۔ اس میں رقم، تاریخ، اندراج کی تفصیل، ادائیگی کی معلومات، آپ کا نام اور فون نمبر شامل ہو سکتے ہیں۔
- دوسرے سائن اِن صارفین آپ کا تصدیق شدہ فون نمبر، نام، تصویر، پیشہ، کاروباری پتہ اور دکان کا نام دیکھ سکتے ہیں۔ دکان کی معلومات، آئٹمز اور ریویوز بھی سائن اِن صارفین کو نظر آ سکتے ہیں۔
- موجودہ ورژن میں مارکیٹ پلیس کی عوامی فہرست سازی بند ہے۔ پہلے ورژن کی موجود لسٹنگ، اگر کوئی ہو، اکاؤنٹ حذف ہونے تک نجی طور پر باقی رہ سکتی ہے۔
- Firebase/Google اکاؤنٹ تصدیق اور کلاؤڈ ہوسٹنگ کی خدمات فراہم کرتے ہیں۔ اس کے علاوہ کنسول میں فعال کسی دوسرے ڈیٹا پراسیسر یا اشتراک کی تصدیق نہیں ہوئی۔

**Firebase کے علاوہ تیسرے فریق، Firebase کی پراسیسنگ شرائط، اور کنسول میں فعال اضافی خدمات:** [تصدیق درکار]

### English
- Your private accounts and transactions are generally limited to your account.
- If a worker’s phone number matches an app account, a copied wage entry may be sent to that worker’s account. It may include the amount, date, entry description, payment information, your name and phone number.
- Other signed-in users can see your verified phone number, name, photo, profession, business address and shop name. Shop information, items and reviews may also be visible to signed-in users.
- Public marketplace listings are disabled in the current version. Any listing from an earlier version, if present, may remain private until account deletion.
- Firebase/Google provide account authentication and cloud-hosting services. Other data processors or sharing enabled in the console have not been verified.

**Third parties beyond Firebase, Firebase processing terms, and other enabled console services:** [Verification required]

## ۶. دوسرے افراد کا ڈیٹا
آپ گاہکوں، سپلائرز اور مزدوروں کے نام، رابطے اور کاروباری ریکارڈ خود درج کر سکتے ہیں۔ صرف وہ معلومات درج کریں جنہیں استعمال کرنے کا آپ کو حق حاصل ہو اور جنہیں متعلقہ فیچر کے مطابق دکھانا یا مزدور کے اکاؤنٹ میں بھیجنا ضروری ہو۔ اس استعمال کے قانونی تقاضوں کا جائزہ درکار ہے۔

### English
You may enter names, contact details and business records about customers, suppliers and workers. Enter only information you are entitled to use and that is necessary for the feature, including any information shown or sent to a worker’s account. Legal review of these practices is required.

## ۷. اجازتیں اور ڈیوائس فیچرز
- **Contacts:** آپ کی درخواست پر رابطہ منتخب کرنے کے لیے۔
- **Camera:** تصاویر لینے یا اسکین کرنے کے لیے، جہاں متعلقہ فیچر استعمال ہو۔
- **Internet:** Firebase اور دیگر نیٹ ورک فیچرز کے لیے۔
- **Biometric/device authentication:** ایپ لاک کھولنے کے لیے۔
- موجودہ ورژن GPS، لوکیشن اجازت، نقشہ، آن لائن پتہ تلاش، آڈیو ریکارڈنگ یا آواز سے تلاش استعمال نہیں کرتا۔ کاروباری پتہ آپ خود درج کرتے ہیں۔

### English
- **Contacts:** To select a contact when you choose to do so.
- **Camera:** To take photos or scan where the relevant feature is used.
- **Internet:** For Firebase and other network features.
- **Biometric/device authentication:** To unlock the app lock.
- The current version does not use GPS, location permission, maps, online address lookup, audio recording or voice search. You enter business addresses manually.

## ۸. ڈیٹا رکھنا، اکاؤنٹ بحال کرنا اور حذف کرنا
سیٹنگز سے اکاؤنٹ حذف کرنے کی درخواست دی جا سکتی ہے۔ درخواست پر اکاؤنٹ فوراً غیر فعال ہوتا ہے اور 30 دن کے اندر دوبارہ لاگ اِن کر کے بحال کیا جا سکتا ہے۔ اس مدت میں دکان کی کچھ معلومات سائن اِن صارفین کو نظر آ سکتی ہیں۔ سرور کوڈ 30 دن کے بعد کلاؤڈ اکاؤنٹ، متعلقہ ریکارڈ، بیک اپ اور اپ لوڈ کردہ فائلیں حذف کرنے کے لیے شیڈول کرتا ہے۔ دوسرے صارفین کے اپنے ریکارڈ میں محفوظ کی گئی آزاد نقلیں باقی رہ سکتی ہیں۔

**اہم تصدیق:** [تصدیق درکار: حذف/بحالی کے Firebase Functions اور 30 دن بعد حذف کرنے والے شیڈولر کو پروڈکشن میں تعینات اور عملی طور پر جانچا گیا ہے یا نہیں۔ جب تک تصدیق نہ ہو، مستقل حذف ہونے کی ضمانت نہ سمجھیں۔]

### English
You can request account deletion in Settings. The account is disabled immediately and can be restored by signing in within 30 days. Some shop information may remain visible to signed-in users during this period. The server code schedules the cloud account, associated records, backups and uploaded files for deletion after 30 days. Independent copies that other users keep in their own records may remain.

**Important verification:** [Verification required: confirm that the Firebase deletion/restoration functions and 30-day purge scheduler are deployed to production and have been tested. Until confirmed, permanent deletion must not be treated as guaranteed.]

## ۹. بچوں کا ڈیٹا
یہ ایپ کاروباری استعمال کے لیے ہے اور بچوں کے لیے نہیں بنائی گئی۔ ایپ میں عمر کی جانچ موجود نہیں۔

**کم از کم عمر اور بچوں کے ڈیٹا سے متعلق پالیسی:** [تصدیق درکار: کاروبار کے مقام اور قابلِ اطلاق قانون کے مطابق عمر اور طریقۂ کار طے کریں۔]

### English
This app is intended for business use and is not designed for children. The app does not verify users’ ages.

**Minimum age and children’s-data policy:** [Verification required: determine the age threshold and approach based on the business location and applicable law.]

## ۱۰. سیکیورٹی
ایپ Firebase سروسز اور Firestore rules استعمال کرتی ہے۔ ایپ لاک اور بایومیٹرک تصدیق ڈیوائس پر رسائی کنٹرول کے لیے ہیں؛ ان سے یہ مراد نہیں کہ تمام کاروباری ریکارڈ الگ سے انکرپٹ کیے گئے ہیں۔ پروفائل اور دکان کی معلومات جو اوپر بیان کی گئی ہیں، دوسرے سائن اِن صارفین کو دکھائی جا سکتی ہیں۔

**Firebase کنسول، سرور کی ترتیبات، بیک اپ تحفظ اور ڈیٹا کی ترسیل/ذخیرہ کرنے کی انکرپشن:** [تصدیق درکار]

### English
The app uses Firebase services and Firestore rules. App lock and biometric authentication control access on the device; they do not mean that all business records are separately encrypted. The profile and shop information described above may be visible to other signed-in users.

**Firebase Console, server configuration, backup protection, and encryption in transit/at rest:** [Verification required]

## ۱۱. پالیسی میں تبدیلی
پالیسی میں تبدیلی ہو تو نظرثانی شدہ تاریخ کے ساتھ ایپ یا متعلقہ صفحے پر اپ ڈیٹ کیا جائے گا۔

### English
If this policy changes, the revised version and date will be posted in the app or on the related page.

## ۱۲. رابطہ
- **سپورٹ ای میل:** [karobarisaathi@gmail.com](mailto:karobarisaathi@gmail.com)
- **قانونی کمپنی/ذمہ دار ادارہ:** [تصدیق درکار: قانونی نام درج کریں]
- **کاروباری پتہ:** [تصدیق درکار: پتہ درج کریں]

### English
- **Support email:** [karobarisaathi@gmail.com](mailto:karobarisaathi@gmail.com)
- **Legal company/responsible entity:** [Verification required: enter the legal name]
- **Business address:** [Verification required: enter the address]

> **قانونی نوٹ:** یہ پالیسی قانونی مشورہ نہیں ہے۔ اشاعت سے پہلے اسے کسی مستند وکیل سے ضرور جانچوائیں۔
>
> **Legal note:** This policy is not legal advice. Have it reviewed by a qualified lawyer before publication.
