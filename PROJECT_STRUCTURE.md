# Project Structure

This is an inventory of the current project files, checked against the working
directory. The Flutter source, tests, assets, and Firebase Functions files are
listed individually. Build output, local machine settings, credentials, and
tool-generated platform files are intentionally excluded.

## Repository root

```text
.
├── .firebaserc
├── .gitignore
├── analysis_options.yaml
├── devtools_options.yaml
├── firebase.json
├── firestore.rules
├── pubspec.yaml
├── pubspec.lock
├── README.md
├── PROJECT_GUIDE.md
├── PROJECT_STRUCTURE.md
└── Karobari_Saathi_Audit_Report.txt
```

Local `.env`, IDE files, and generated Flutter/Gradle files may exist in a
developer's checkout; they are not application source and are not listed.
Never add credentials, signing keys, or private environment values to this
document or source control.

## Flutter application (`lib/`)

```text
lib/
├── app.dart
├── main.dart
├── firebase_options.dart
├── core/
│   ├── config/
│   │   ├── ai_prompts.dart
│   │   ├── app_roles.dart
│   │   └── professions_config.dart
│   ├── constants/
│   │   └── quick_bill_constants.dart
│   ├── models/
│   │   ├── account_model.dart
│   │   ├── account_model.g.dart
│   │   ├── analytics_model.dart
│   │   ├── category_model.dart
│   │   ├── category_model.g.dart
│   │   ├── dispute_model.dart
│   │   ├── dispute_model.g.dart
│   │   ├── notification_model.dart
│   │   ├── notification_model.g.dart
│   │   ├── profession_model.dart
│   │   ├── profession_model.g.dart
│   │   ├── season_report_model.dart
│   │   ├── shop_model.dart
│   │   ├── stock_analytics_model.dart
│   │   ├── stock_category_model.dart
│   │   ├── stock_item_model.dart
│   │   ├── stock_movement_model.dart
│   │   ├── transaction_item_model.dart
│   │   ├── transaction_item_model.g.dart
│   │   ├── transaction_model.dart
│   │   └── transaction_model.g.dart
│   ├── services/
│   │   ├── alert_service.dart
│   │   ├── analytics_service.dart
│   │   ├── auth_service.dart
│   │   ├── auto_sync_service.dart
│   │   ├── backup_service.dart
│   │   ├── balance_service.dart
│   │   ├── database_service.dart
│   │   ├── deep_link_service.dart
│   │   ├── excel_service.dart
│   │   ├── firebase_service.dart
│   │   ├── item_catalog_service.dart
│   │   ├── language_service.dart
│   │   ├── location_service.dart
│   │   ├── logging_service.dart
│   │   ├── notification_service.dart
│   │   ├── pdf_service.dart
│   │   ├── recommendation_engine.dart
│   │   ├── season_report_service.dart
│   │   ├── security_service.dart
│   │   ├── stock_analytics_service.dart
│   │   ├── stock_service.dart
│   │   ├── theme_service.dart
│   │   ├── usage_limit_service.dart
│   │   ├── version_check_service.dart
│   │   └── database/
│   │       ├── account_service.dart
│   │       ├── base_service.dart
│   │       ├── category_service.dart
│   │       ├── profession_service.dart
│   │       ├── profile_service.dart
│   │       ├── settings_service.dart
│   │       ├── sync_service.dart
│   │       └── transaction_service.dart
│   ├── theme/
│   │   └── app_theme.dart
│   ├── utils/
│   │   ├── account_balance_utils.dart
│   │   ├── arabic_reshaper.dart
│   │   ├── bill_numbering.dart
│   │   ├── constants.dart
│   │   ├── date_utils.dart
│   │   ├── file_utils.dart
│   │   ├── formatters.dart
│   │   ├── helpers.dart
│   │   ├── image_utils.dart
│   │   ├── pdf_preview.dart
│   │   ├── receipt_dialog_helper.dart
│   │   ├── rtl_wrapper.dart
│   │   ├── validators.dart
│   │   └── voice_recorder.dart
│   └── widgets/
│       ├── app_button.dart
│       ├── app_filter_chip.dart
│       ├── app_toast.dart
│       ├── category_chip.dart
│       ├── custom_app_bar.dart
│       ├── image_gallery_viewer.dart
│       ├── image_selector_field.dart
│       ├── in_app_notification_banner.dart
│       ├── item_rate_history_card_widget.dart
│       ├── language_aware_text.dart
│       ├── location_chip_widget.dart
│       ├── main_bottom_nav_bar.dart
│       ├── notification_card.dart
│       ├── party_card.dart
│       ├── profile_info_widget.dart
│       ├── profile_update_dialog.dart
│       ├── search_sort_bar.dart
│       ├── simple_spinning_ring.dart
│       ├── skeleton_shimmer.dart
│       ├── stock_card.dart
│       ├── transaction_card.dart
│       ├── urdu_aware_text.dart
│       └── voice_comment_player.dart
├── features/
│   ├── accounts/
│   │   ├── add_party_screen.dart
│   │   ├── add_transaction_screen.dart
│   │   ├── bulk_party_transaction_screen.dart
│   │   ├── party_detail_screen.dart
│   │   ├── party_list_screen.dart
│   │   ├── reports_screen.dart
│   │   ├── sms_invitation_screen.dart
│   │   └── widgets/
│   │       └── party_tools_grid_widget.dart
│   ├── dashboard/
│   │   └── app_shell_screen.dart
│   ├── notifications/
│   │   └── notifications_screen.dart
│   ├── order/
│   │   ├── my_orders_screen.dart
│   │   ├── nearby_shops_screen.dart
│   │   ├── shop_detail_screen.dart
│   │   ├── shop_orders_screen.dart
│   │   ├── services/
│   │   │   └── shop_order_service.dart
│   │   └── widgets/
│   │       ├── shop_card_widget.dart
│   │       └── shop_item_card_widget.dart
│   ├── professions/
│   │   ├── add_project_transaction_screen.dart
│   │   ├── categories_management_screen.dart
│   │   ├── complete_season_screen.dart
│   │   ├── profession_dialog.dart
│   │   ├── profession_seasons_screen.dart
│   │   ├── professions_screen.dart
│   │   └── season_comparison_screen.dart
│   ├── profile/
│   │   └── controllers/
│   │       └── profile_controller.dart
│   ├── quick_bill/
│   │   ├── quick_bill_item_selection_screen.dart
│   │   ├── quick_bill_preview_screen.dart
│   │   └── widgets/
│   │       ├── base_ledger_widget.dart
│   │       ├── customer_picker_sheet.dart
│   │       ├── incoming_receipt_widget.dart
│   │       └── outgoing_receipt_widget.dart
│   ├── settings/
│   │   ├── app_lock_screen.dart
│   │   ├── backup_screen.dart
│   │   ├── login_screen.dart
│   │   └── master_profile_screen.dart
│   └── shopkeeper/
│       ├── add_edit_stock_item_screen.dart
│       ├── low_stock_items_screen.dart
│       ├── sales_analytics_screen.dart
│       ├── shop_settings_screen.dart
│       ├── shopkeeper_dashboard_screen.dart
│       ├── stock_adjustment_dialog.dart
│       ├── stock_detail_screen.dart
│       ├── stock_history_screen.dart
│       └── widgets/
│           └── shopkeeper_tools_grid.dart
├── helpers/
│   └── migration_helper.dart
└── l10n/
    ├── app_localizations.dart
    ├── app_localizations_en.dart
    ├── app_localizations_ur.dart
    └── l10n.yaml
```

Files ending in `.g.dart` and generated localization files are generator
outputs. Keep them with their source as required by Flutter/Dart tooling; do
not hand-edit generated code.

## Tests (`test/`)

```text
test/
├── analytics_service_test.dart
├── formatters_test.dart
├── profession_categories_test.dart
├── stock_analytics_service_test.dart
├── widget_test.dart
├── core/
│   └── widgets/
│       └── urdu_aware_text_test.dart
├── models/
│   ├── stock_item_model_test.dart
│   ├── stock_movement_balance_test.dart
│   ├── transaction_balance_amount_test.dart
│   └── transaction_stock_link_test.dart
└── utils/
    ├── account_balance_utils_test.dart
    └── bill_numbering_test.dart
```

## Assets (`assets/`)

```text
assets/
├── avatars/
│   ├── avatar.svg
│   ├── avatar (1).svg
│   ├── avatar (2).svg
│   ├── avatar (3).svg
│   ├── avatar (4).svg
│   ├── avatar (5).svg
│   ├── avatar (6).svg
│   └── avatar (7).svg
├── fonts/
│   ├── GulzarRegular.ttf
│   ├── NooriNastaleeq.ttf
│   ├── NotoSans-Bold.ttf
│   ├── NotoSans-Regular.ttf
│   ├── NotoSansArabic-Bold.ttf
│   └── NotoSansArabic-Regular.ttf
└── images/
    └── icons/
        └── zalooq.png
```

## Firebase Functions (`functions/`)

```text
functions/
├── .gitignore
├── index.js
├── package.json
└── package-lock.json
```

## Platform folders

These are standard Flutter platform projects. Their source/configuration is
kept in the platform-specific folders; generated plugin registrants, build
outputs, caches, local SDK settings, and signing material are intentionally
not duplicated in this inventory.

```text
android/
├── app/
│   ├── build.gradle.kts
│   ├── proguard-rules.pro
│   └── src/
├── gradle/
│   └── wrapper/
├── build.gradle.kts
├── gradle.properties
├── gradlew
├── gradlew.bat
└── settings.gradle.kts

ios/
├── Flutter/
├── Runner/
├── Runner.xcodeproj/
├── Runner.xcworkspace/
└── RunnerTests/

linux/
├── flutter/
└── runner/

macos/
├── Flutter/
├── Runner/
├── Runner.xcodeproj/
├── Runner.xcworkspace/
└── RunnerTests/

web/
├── icons/
├── favicon.png
├── index.html
└── manifest.json

windows/
├── flutter/
└── runner/
```

## Organization rules for future changes

- Put a screen, controller, service, and widget inside its feature when it is
  only used by that feature. The existing `order` feature follows this pattern.
- Put code in `core/` only when it is shared across features or is app-wide
  infrastructure. Keep feature-only code out of shared folders.
- Keep database implementations in `core/services/database/`; avoid creating
  a duplicate data-access layer without a clear requirement.
- Keep generated files beside their source when required by their generator.
- If a file is moved, update imports and tests in the same change, then run
  `flutter analyze` and relevant `flutter test` cases.
- Add new files to this inventory when adding them to the project.
