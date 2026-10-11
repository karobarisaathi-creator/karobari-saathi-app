# Project Structure

This diagram reflects the current Dart source tree under `lib/`.

```text
lib/
├── main.dart
├── app.dart
├── firebase_options.dart
├── core/
│   ├── config/
│   │   ├── ai_prompts.dart
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
│   │   ├── stock_analytics_model.dart
│   │   ├── stock_category_model.dart
│   │   ├── stock_item_model.dart
│   │   ├── stock_movement_model.dart
│   │   ├── transaction_item_model.dart
│   │   ├── transaction_item_model.g.dart
│   │   ├── transaction_model.dart
│   │   └── transaction_model.g.dart
│   ├── services/
│   │   ├── database/
│   │   │   ├── account_service.dart
│   │   │   ├── base_service.dart
│   │   │   ├── category_service.dart
│   │   │   ├── profession_service.dart
│   │   │   ├── profile_service.dart
│   │   │   ├── settings_service.dart
│   │   │   ├── sync_service.dart
│   │   │   └── transaction_service.dart
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
│   │   └── version_check_service.dart
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
│   │   ├── receipt_helper.dart
│   │   ├── rtl_wrapper.dart
│   │   ├── validators.dart
│   │   └── voice_recorder.dart
│   └── widgets/
│       ├── app_button.dart
│       ├── app_drawer.dart
│       ├── app_filter_chip.dart
│       ├── app_toast.dart
│       ├── category_chip.dart
│       ├── custom_app_bar.dart
│       ├── image_gallery_viewer.dart
│       ├── image_selector_field.dart
│       ├── in_app_notification_banner.dart
│       ├── language_aware_text.dart
│       ├── location_map_widget.dart
│       ├── notification_card.dart
│       ├── party_card.dart
│       ├── profile_info_widget.dart
│       ├── search_sort_bar.dart
│       ├── simple_spinning_ring.dart
│       ├── skeleton_shimmer.dart
│       ├── stock_card.dart
│       ├── transaction_card.dart
│       └── voice_comment_player.dart
├── features/
│   ├── accounts/
│   │   ├── add_party_screen.dart
│   │   ├── add_transaction_screen.dart
│   │   ├── bulk_party_transaction_screen.dart
│   │   ├── party_detail_screen.dart
│   │   ├── party_history_screen.dart
│   │   ├── reports_screen.dart
│   │   └── sms_invitation_screen.dart
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   └── main_navigation_screen.dart
│   ├── notifications/
│   │   └── notifications_screen.dart
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
│   │   ├── widgets/
│   │   │   ├── customer_picker_sheet.dart
│   │   │   └── receipt_widget.dart
│   │   ├── quick_bill_item_selection_screen.dart
│   │   └── quick_bill_preview_screen.dart
│   ├── settings/
│   │   ├── app_lock_screen.dart
│   │   ├── backup_screen.dart
│   │   ├── login_screen.dart
│   │   └── master_profile_screen.dart
│   └── shopkeeper/
│       ├── add_edit_stock_item_screen.dart
│       ├── low_stock_items_screen.dart
│       ├── sales_analytics_screen.dart
│       ├── shopkeeper_dashboard_screen.dart
│       ├── stock_adjustment_dialog.dart
│       ├── stock_detail_screen.dart
│       └── stock_history_screen.dart
├── helpers/
│   └── migration_helper.dart
└── l10n/
    ├── app_localizations.dart
    ├── app_localizations_en.dart
    ├── app_localizations_ur.dart
    └── l10n.yaml
```

Generated files (such as `*.g.dart` and `app_localizations*.dart`) are included because they are present in the current source tree. This is an inventory, not a proposed reorganization; the current project does not yet contain the role-based and personal-finance files shown in the example structure.
