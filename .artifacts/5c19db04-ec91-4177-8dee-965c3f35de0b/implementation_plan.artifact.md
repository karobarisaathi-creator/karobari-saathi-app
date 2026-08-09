# Artisan Profile Screen Improvements

This plan addresses three main requests from the user:
1. Fix the empty name field on the profile screen.
2. Remove the "Amount" (Rate) field.
3. Remove the "Show Phone Number" option.

## User Review Required

> [!IMPORTANT]
> The "Show Phone Number" option is being removed. By default, the profile will be saved with `showPhone: true`.
> The "Rate" field is being removed entirely from the UI and will be saved as `null`.

## Proposed Changes

### Artisan Feature

#### [MODIFY] [artisan_profile_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/artisans/artisan_profile_screen.dart)
- Update `_loadExistingProfile` to fetch the user's name from Firestore if it's missing from `FirebaseAuth`.
- Remove `TextEditingController` for the rate field.
- Remove the "Show Phone Number" switch and the "Rate" text field from the UI.
- Update `_saveProfile` to ignore the removed fields.

## Verification Plan

### Manual Verification
- Open the Artisan Profile screen and verify that the name field is automatically populated.
- Verify that the "Amount" (Rate) field is no longer visible.
- Verify that the "Show Phone Number" option is no longer visible.
- Save the profile and ensure no errors occur.
