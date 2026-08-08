# Dashboard Balance Card Update

Update the Dashboard's balance summary to reflect the aggregate of party balances (Receivables and Payables) instead of raw transaction totals. This ensures consistency between the "Party Cards" and the "Balance Card" as requested by the user.

## User Review Required

> [!NOTE]
> The "Total In" and "Total Out" labels on the dashboard will be changed to "To Receive" (لینے ہیں) and "To Pay" (دینے ہیں) to match the terminology used in the Party Cards.

## Proposed Changes

### Dashboard Component

#### [MODIFY] [dashboard_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/dashboard/dashboard_screen.dart)

- Update the calculation logic for party balances in the `Consumer<DatabaseService>` builder.
- Iterate through each active party, calculate its net balance, and categorize it as either "Receivable" (لینے ہیں) or "Payable" (دینے ہیں).
- Replace the raw transaction sums (`totalTaken`, `totalGiven`) with these aggregate totals.
- Update the labels in the `_buildBalanceItem` widgets to "To Receive", "To Pay", and "Net Balance".
- Ensure the third item in the balance card correctly displays whether the net amount is a credit or debit overall.

## Verification Plan

### Manual Verification
- Deploy the app and navigate to the Dashboard.
- Verify that the "To Receive" total matches the sum of all party cards showing "لینے ہیں".
- Verify that the "To Pay" total matches the sum of all party cards showing "دینے ہیں".
- Check that the "Net Balance" is correctly calculated as the difference between the two.
- Toggle between English and Urdu to ensure labels are correct in both languages.
