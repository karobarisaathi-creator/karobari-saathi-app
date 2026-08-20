# Admin Screen UI Update & User Count Fix

This plan details the UI improvements for the Admin Control Panel, including a custom pill-style TabBar, a new search bar placement, and displaying the total user count.

## Proposed Changes

### [Admin Feature]

#### [MODIFY] [admin_verification_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/settings/admin_verification_screen.dart)

- **Custom Pill-Style TabBar:**
    - Move `TabBar` from `AppBar.bottom` to the `body` within a `Column`.
    - Apply a pill-shaped background to the `TabBar` container.
    - Use a white pill indicator for the selected tab (matching the provided image).
    - Update tab colors to better fit the new design (e.g., dark text on light background).

- **Search Bar Placement:**
    - Add a compact "Search Short Bar" below the `TabBar`.
    - This search bar will be visible across all tabs (if requested) or I can keep it tab-specific but styled as a "short bar". *Decision: I will place it in a common header below the TabBar so it's consistent.*

- **User Count Visibility:**
    - In the "Users" tab, add a header displaying the total number of users.
    - Use `VerificationService.getAppStatsStream()` to fetch the real-time count.

## Verification Plan

### Manual Verification
- Deploy to device/emulator.
- Navigate to the Admin Control Panel.
- Verify the TabBar design matches the pill shape in the image.
- Verify the search bar is present below the TabBar.
- Switch to the "Users" tab and verify the total user count is displayed.
- Test searching by phone number to ensure functionality remains intact.
