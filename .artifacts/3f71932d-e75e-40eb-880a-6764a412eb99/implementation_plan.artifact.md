# Artisan Feature Improvements Plan

This plan addresses several logic, data integrity, and UX issues identified in the Artisan feature.

## Proposed Changes

### 1. Data Integrity: Rating Transactions
[MODIFY] [artisan_service.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core/services/artisan_service.dart)
- Update `_updateArtisanRating` to use Firestore Transactions. This ensures that concurrent ratings don't overwrite each other and the average remains accurate.

### 2. Logic Flaw: Work Order Customer Identification
[MODIFY] [artisan_work_orders_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/artisans/artisan_work_orders_screen.dart)
- When an artisan manually adds a work order, the `customerId` should NOT be the artisan's own UID.
- It will be set to a special string `manual_entry` if no app user is linked.

### 3. UX & Status: Price Negotiation Improvements
[MODIFY] [artisan_work_orders_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/artisans/artisan_work_orders_screen.dart)
- Update status to `quoted` when the artisan provides a price.
- Trigger a notification to the customer (if linked) using `NotificationService`.
[MODIFY] [artisan_work_order_service.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core/services/artisan_work_order_service.dart)
- Add `quoted` status handling in service methods if necessary.

### 4. Security: Basic Action Validation
[MODIFY] [artisan_work_order_service.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core/services/artisan_work_order_service.dart)
- Add basic UID checks to ensure only the owner can update status/price.

## Verification Plan

### Manual Verification
- **Rating Test:** Add multiple reviews to an artisan and verify the average rating updates correctly.
- **Work Order Test:** Add a manual work order as an artisan and check if the `customerId` is correct in Firestore.
- **Price Test:** Enter a price for a work order and verify the status changes to `quoted`.
- **Notification Test:** (Simulated) Check if `NotificationService` is called when a quote is sent.
