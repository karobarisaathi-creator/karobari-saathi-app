# Unified Verification Badge Style

The goal is to ensure the "Verified" gold badge is displayed consistently next to the profile name across all screens, matching the style used in the `PartyCard` (which uses `ProfileInfoWidget`).

## Proposed Changes

### [Core Component](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core)

#### [MODIFY] [profile_info_widget.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/core/widgets/profile_info_widget.dart)
- Ensure the badge size and spacing are perfectly balanced with the text.
- Standardize the badge size to `14` for regular text and `18` for large text.

### [Inventory Component](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/inventory)

#### [MODIFY] [item_detail_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/inventory/item_detail_screen.dart)
- Update `_buildSellerCard` to use the same logic as `ProfileInfoWidget`.
- Adjust badge size to `14` to match the name font size (`16`) more gracefully.

#### [MODIFY] [seller_items_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/inventory/seller_items_screen.dart)
- Update the header name section to ensure the badge size and alignment match the unified style.

### [Visual Finder Component](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/visual_finder)

#### [MODIFY] [local_seller_card.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/visual_finder/widgets/local_seller_card.dart)
- Ensure the badge next to the seller name matches the unified size and spacing.

## Verification Plan

### Manual Verification
- **Party List**: Check the `PartyCard` to confirm the baseline style.
- **Item Detail**: Verify the seller section shows the badge correctly next to the name.
- **Seller Profile**: Verify the header shows the badge correctly.
- **Visual Finder**: Verify search results show the badge next to seller names.
