# Smart Diary "Khata Sync" Upgrade Tasks

- [ ] **Transaction Screen Enhancement**
    - [ ] Update `AddTransactionScreen` to accept `initialDescription` and `initialAmount` [:app/lib/features/accounts/add_transaction_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/accounts/add_transaction_screen.dart)
    - [ ] Handle these fields in `initState` to pre-fill the item list.

- [ ] **Diary UI Refinement (PersonDiaryScreen)**
    - [ ] Relocate Date and Action buttons (Edit/Delete/Khata) to a single row **below** the text [:app/lib/features/dashboard/person_diary_screen.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/dashboard/person_diary_screen.dart)
    - [ ] Reduce line spacing and padding for a compact look.
    - [ ] Add the "Add to Khata" button (Icon: `PhosphorIcons.bookBookmark`).

- [ ] **Logic & Navigation**
    - [ ] Implement navigation from Diary entry to `AddTransactionScreen`.
    - [ ] Ensure amount extraction from `WorkLog` is correct (Pure numbers).

- [ ] **Final Verification**
    - [ ] Verify compact layout.
    - [ ] Test "Add to Khata" flow and ensure data is pre-filled correctly.
