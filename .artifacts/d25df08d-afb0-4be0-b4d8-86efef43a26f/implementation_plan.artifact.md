# Fix Transaction Lag, Rate History, and Search Bar UI

This plan addresses three issues reported by the user:
1. **Transaction Lag:** The `AddTransactionScreen` stays on the loading spinner even after saving.
2. **Rate History:** `PartyHistoryScreen` doesn't record rate changes for items "given" (expense transactions).
3. **Search Bar UI:** The search bar in `DashboardScreen` is too close to the header.

## Proposed Changes

### 1. [Accounts Component](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/accounts)

#### [MODIFY] [add_transaction_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/accounts/add_transaction_screen.dart)
- Improve the `_saveTransaction` logic to ensure `Navigator.pop(context)` is called reliably.
- Add a small delay if necessary or ensure `_isLoading` is set to `false` before `pop` to avoid UI flicker/stalling.

#### [MODIFY] [party_history_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/accounts/party_history_screen.dart)
- Update the `_loadData` method to process both `income` and `expense` transactions for rate history.
- The user specifically mentioned that items "given" (expenses) are not being recorded, so we will remove the `if (tx.type != 'income') continue;` restriction.

### 2. [Dashboard Component](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/dashboard)

#### [MODIFY] [dashboard_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/dashboard/dashboard_screen.dart)
- Increase the top padding for the search bar and command center in the `_buildPartyList` method to separate them from the header.

## Verification Plan

### Manual Verification
- **Transaction Save:** Add a new transaction and verify the screen closes automatically without sticking on the loading spinner.
- **Rate History:** Add an "Expense" transaction with a specific item and rate, then add another with a different rate. Verify the `PartyHistoryScreen` shows the rate difference for that item.
- **UI Layout:** Open the Dashboard and verify the search bar has comfortable breathing room from the dark header.
