# Artisan Feature Improvements - "Stamp Paper" Workflow

This plan outlines the necessary steps to support the new "Stamp Paper" style job posting feature, ensuring data persistence and UI enhancements.

## Proposed Changes

### 1. Data Models Update
#### [MODIFY] [job_post_model.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core/models/job_post_model.dart)
- Add fields: `detailedScope`, `scopeOfWork`, `exclusions`, `isComplex`, `estimatedDays`.
- Update `toMap` and `fromMap` to handle these fields.
- Update Hive fields (Fields 17-21).

### 2. UI Enhancements
#### [MODIFY] [post_job_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/artisans/screens/post_job_screen.dart)
- Improve the "Stamp Paper" container styling.
- Add better Urdu typography support for numbered lists.
- Ensure validation for mandatory "Work Details".

### 3. Service Layer Integration
#### [MODIFY] [job_service.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core/services/database/job_service.dart)
- Ensure the `selectBid` logic correctly transfers the `detailedScope` and `exclusions` to the `ArtisanWorkOrder`.

## Verification Plan
### Manual Verification
- Post a job with multiple numbered details and exclusions.
- Verify data is correctly saved in Firestore.
- Check if the "Stamp Paper" section looks consistent in both English and Urdu.
