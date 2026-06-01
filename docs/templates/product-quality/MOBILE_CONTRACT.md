# Mobile Contract

Purpose: keep customer-facing and phone-check workflows usable on small screens.

Required fields:
- Target viewport
- Primary mobile action
- First-screen mobile screenshot
- Navigation pattern
- Text wrapping expectation
- Tap target expectation
- What must not appear first on mobile

Customer-facing requirement:
- Mobile evidence is required.

Manager/internal requirement:
- Mobile evidence is recommended when the operator may check it on the floor.

Analytical/backend-only exception:
- Mark NOT_APPLICABLE only when no human-facing mobile surface exists.

Failure example:
```text
Mobile opens halfway down a giant table or form, with no orientation or primary action.
```

