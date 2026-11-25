# Home Activity Feed — Message Drafts

یہ صرف پیغامات کا مسودہ ہے تاکہ منظوری سے پہلے آپ اسے دیکھ سکیں۔ ابھی اس فائل سے ایپ کا رویہ تبدیل نہیں ہوتا۔

## متغیر معلومات

`{...}` کے اندر لکھی چیزیں ایپ اصل ریکارڈ سے بھرے گی:

| متغیر | مطلب |
|---|---|
| `{senderName}` | بھیجنے والے کا نام، اس کے تصدیق شدہ پروفائل سے |
| `{amount}`، `{totalAmount}`، `{receivedAmount}`، `{pendingAmount}`، `{discountAmount}`، `{wageAmount}` | ایپ کی کرنسی کی ترتیب کے مطابق پہلے سے فارمیٹ شدہ رقم (علامت سمیت)، اس لیے جملوں میں "روپے" یا "Rs." الگ نہیں لکھا |
| `{itemList}` | اشیاء کے نام اور مقدار، زیادہ سے زیادہ تین؛ باقی کے لیے "اور {moreCount} مزید" |
| `{jobName}`، `{contractName}` | کام یا ٹھیکے کا نام (اختیاری، نہ ہو تو جملے کا وہ حصہ چھوڑ دیا جائے) |
| `{wageBasis}` | مزدوری کی بنیاد: `روزانہ` / `فی کام` / `ماہانہ` (انگریزی: `per day` / `per job` / `per month`) |
| `{days}` | حاضر دنوں کی تعداد |

## الفاظ جو ہر جگہ ایک جیسے رہیں گے

| اردو | English |
|---|---|
| کھاتہ (آپ کی کتاب) | ledger |
| پارٹی کھاتہ | party account |
| مزدوری (اجرت نہیں) | wages |
| ادا کرنا / وصول کرنا | pay / receive |

## 1. کھاتے کا لین دین

**کب دکھائیں:** جب کسی دوسرے صارف نے اپنے کھاتے میں آپ کے ساتھ لین دین درج کیا ہو۔ رقم بھیجنے والے کے کھاتے میں درج ہے؛ آپ کے کھاتے میں وہ تب آئے گی جب آپ "کھاتے میں شامل کریں" دبائیں۔

| صورت | اردو | English |
|---|---|---|
| بھیجنے والے نے آپ کو رقم دی | `{senderName} نے آپ کو {amount} ادا کرنا درج کیا ہے۔` | `{senderName} recorded a payment of {amount} to you.` |
| بھیجنے والے نے آپ سے رقم لی | `{senderName} نے آپ سے {amount} وصول کرنا درج کیا ہے۔` | `{senderName} recorded receiving {amount} from you.` |
| آپ کے ذمے رقم | `{senderName} کے کھاتے میں آپ کے ذمے {amount} درج ہوئے ہیں۔` | `{senderName}'s ledger shows you owe {amount}.` |
| بھیجنے والے کے ذمے رقم | `{senderName} کے کھاتے میں ان کے ذمے آپ کے {amount} درج ہوئے ہیں۔` | `{senderName}'s ledger shows they owe you {amount}.` |
| سمت معلوم نہ ہو | `{senderName} نے آپ کے ساتھ {amount} کا لین دین درج کیا ہے۔` | `{senderName} recorded a transaction of {amount} with you.` |

## 2. فوری بل

### 2.1 بھیجنے والے نے آپ کو بل بھیجا (آپ نے خریدا)

**کب دکھائیں:** جب دکاندار آپ کے نمبر پر فوری بل بھیجے۔

**بل میں اشیاء ہوں:**

- **اردو:** `{senderName} نے آپ کے نام بل بھیجا ہے: {itemList}۔`
- **English:** `{senderName} sent you a bill for: {itemList}.`

**بل میں اشیاء کی فہرست نہ ہو:**

- **اردو:** `{senderName} نے آپ کو {totalAmount} کا فوری بل بھیجا ہے۔`
- **English:** `{senderName} sent you a quick bill for {totalAmount}.`

**رقم کی سطر (رعایت نہ ہو):**

- **اردو:** `کل بل: {totalAmount}۔ وصول شدہ: {receivedAmount}۔ بقایا: {pendingAmount}۔`
- **English:** `Bill total: {totalAmount}. Received: {receivedAmount}. Due: {pendingAmount}.`

**رقم کی سطر (رعایت ہو):**

- **اردو:** `کل بل: {totalAmount}۔ رعایت: {discountAmount}۔ وصول شدہ: {receivedAmount}۔ بقایا: {pendingAmount}۔`
- **English:** `Bill total: {totalAmount}. Discount: {discountAmount}. Received: {receivedAmount}. Due: {pendingAmount}.`

### 2.2 بھیجنے والے نے آپ سے خریداری درج کی

- **اردو:** `{senderName} نے آپ سے یہ چیزیں خریدی ہیں: {itemList}۔`
- **English:** `{senderName} bought these items from you: {itemList}.`
- **اردو، رقم:** `کل بل: {totalAmount}۔ ادا شدہ: {receivedAmount}۔ ان کے ذمے: {pendingAmount}۔`
- **English, amounts:** `Bill total: {totalAmount}. Paid: {receivedAmount}. They owe you: {pendingAmount}.`

## 3. مزدور کو کام میں شامل کرنا

**کب دکھائیں:** جب کام کا مالک کسی ایپ استعمال کرنے والے مزدور کو اپنے کام میں شامل کرے۔

**مزدوری طے ہو:**

- **اردو:** `{senderName} نے آپ کو بطور مزدور {jobName} میں شامل کیا ہے۔ طے شدہ مزدوری {wageBasis} {wageAmount} ہے۔`
- **English:** `{senderName} added you as a worker on {jobName}. Agreed wage: {wageAmount} {wageBasis}.`

**مزدوری طے نہ ہوئی ہو:**

- **اردو:** `{senderName} نے آپ کو بطور مزدور {jobName} میں شامل کیا ہے۔ مزدوری ابھی طے نہیں ہوئی۔`
- **English:** `{senderName} added you as a worker on {jobName}. The wage has not been agreed yet.`

**کام کا نام نہ ہو:** اردو میں `{jobName} میں` کی جگہ `کام میں`، انگریزی میں `on {jobName}` کی جگہ `on a job`۔

## 4. واجب مزدوری

**کب دکھائیں:** جب حاضری کے حساب سے مزدور کی مزدوری واجب الادا درج ہو۔ یہ صرف اطلاع ہے (اس پر "کھاتے میں شامل کریں" نہیں)۔

**رقم کے ساتھ:**

- **اردو:** `{senderName} کے حساب سے آپ کی {amount} مزدوری واجب ہے۔`
- **English:** `According to {senderName}'s records, {amount} in wages is due to you.`

**حاضری کے خلاصے کے ساتھ:**

- **اردو:** `{senderName} کے ہاں آپ کی {days} دن حاضری لگی؛ واجب مزدوری {amount}۔`
- **English:** `{senderName} marked you present for {days} days; wages due: {amount}.`

## 5. مزدوری کی ادائیگی

**کب دکھائیں:** جب مالک مزدور کو مزدوری ادا شدہ درج کرے۔

- **اردو:** `{senderName} نے آپ کو {amount} مزدوری ادا کی ہے۔`
- **English:** `{senderName} paid you {amount} in wages.`

## 6. ٹھیکے کی قسط

**کب دکھائیں:** جب ٹھیکے کی قسط کی وصولی یا ادائیگی درج ہو۔

**بھیجنے والے نے آپ سے قسط وصول کی:**

- **اردو:** `{senderName} نے آپ سے {contractName} کی قسط {amount} وصول کی ہے۔`
- **English:** `{senderName} received an installment of {amount} from you for {contractName}.`

**بھیجنے والے نے آپ کو قسط ادا کی:**

- **اردو:** `{senderName} نے آپ کو {contractName} کی قسط {amount} ادا کی ہے۔`
- **English:** `{senderName} paid you an installment of {amount} for {contractName}.`

**ٹھیکے کا نام نہ ہو:** اردو میں `{contractName} کی` کی جگہ `ٹھیکے کی`، انگریزی میں `for {contractName}` کی جگہ `for a contract`۔

## 7. بٹن، حالت اور عمومی پیغامات

| موقع | اردو | English |
|---|---|---|
| لین دین اپنے کھاتے میں شامل کرنے کا بٹن | کھاتے میں شامل کریں | Add to my ledger |
| تفصیل کھولنے کا بٹن | تفصیل دیکھیں | View details |
| نظر انداز کرنے کا بٹن | نظر انداز کریں | Dismiss |
| شکایت کا بٹن | رپورٹ کریں | Report |
| لین دین شامل ہو گیا | لین دین آپ کے کھاتے میں شامل ہو گیا۔ | Transaction added to your ledger. |
| لین دین پہلے شامل ہے | یہ لین دین پہلے ہی آپ کے کھاتے میں شامل ہے۔ | This transaction is already in your ledger. |
| کوئی سرگرمی نہ ہو | ابھی کوئی نئی سرگرمی نہیں۔ | No new activity yet. |
| متعلقہ پارٹی کھاتہ نہ ملے | متعلقہ پارٹی کھاتہ نہیں ملا؛ اسے شامل کرنے کے لیے نیا کھاتہ بنائیں۔ | No matching party account found. Create one to add this entry. |
| ایک سے زیادہ مماثل کھاتے ملیں | ایک سے زیادہ مماثل کھاتے ملے؛ درست کھاتہ منتخب کریں۔ | More than one account matches. Choose the right one. |
| شامل کرنے میں ناکامی | لین دین کھاتے میں شامل نہیں ہو سکا۔ دوبارہ کوشش کریں۔ | Could not add the transaction. Please try again. |

## منظوری کے لیے نوٹ

- یہ سرگرمیاں ہوم اسکرین کے اندر دکھانے کے لیے مجوزہ عبارتیں ہیں؛ ان کے لیے فون پر push notification نہیں بھیجی جائے گی۔
- `{senderName}` ہمیشہ بھیجنے والے کے تصدیق شدہ پروفائل سے آئے گا، اطلاع کے متن میں لکھے نام سے نہیں۔
- "پہلے ہی شامل ہے" کی جانچ لین دین کی شناخت (`transactionId`) سے ہوگی، تاکہ ایک اطلاع سے دو بار اندراج نہ ہو۔
- مزدوری کی شرح کے ساتھ اس کی بنیاد بھی دکھائی جائے گی۔ طے نہ ہونے کی صورت میں رقم گھڑ کر نہیں دکھائی جائے گی۔
- فوری بل کی قیمتیں اور رعایتیں بل کی تفصیل میں دکھائی جا سکتی ہیں؛ فیڈ میں صرف اشیاء کے نام اور مقدار۔
- براہِ کرم عبارتیں اور "کھاتے میں شامل کریں" کا عمل منظور یا درست کر دیں؛ اس کے بعد ہی ان کے مطابق ایپ کا کام بدلا جائے گا۔
