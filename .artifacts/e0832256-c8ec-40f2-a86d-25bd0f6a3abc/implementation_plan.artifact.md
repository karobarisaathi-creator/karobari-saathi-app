# Implementation Plan - Smart Artisan Ranking System

Update the artisan sorting logic in the `ArtisansTab` to use a weighted points-based system instead of a strict sequential sort. This will provide a more balanced recommendation to users by considering availability, distance, verification, rating, and experience simultaneously.

## Proposed Changes

### [Artisans Feature]

#### [MODIFY] [artisans_tab.dart](file:///C:/Users/z/StudioProjects/account_app/account_app/lib/features/artisans/widgets/tabs/artisans_tab.dart)
- Implement a `_calculateArtisanScore` helper method within the `_ArtisansTabState` class.
- Update the `filtered.sort` logic in the `build` method to use the calculated score.
- The scoring system will follow the user's proposed weights:
    - **Availability**: +30 points if "available".
    - **Distance**: +25 points if distance is less than 5km.
    - **Verification**: +20 points if the artisan is verified.
    - **Rating**: +15 points if the rating is 4.5 or higher.
    - **Experience**: +10 points if experience is 5 years or more.
- Maintain the user's selected sort criteria (Rating, Distance, Experience, Reviews) as a tie-breaker when scores are equal.

## Verification Plan

### Manual Verification
- Deploy the app and navigate to the Artisans tab.
- Observe the default sorting order and verify it reflects the weighted scoring (e.g., a verified, highly-rated artisan who is busy might rank higher than an available but unverified/new artisan).
- Change the "Sort By" chips and verify that they still influence the order when scores are similar.
- Toggle availability/verification status for test artisans in Firestore and verify the list updates accordingly.
