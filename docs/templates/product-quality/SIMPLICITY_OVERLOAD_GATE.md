# Simplicity And Overload Gate

Purpose: flag all-features-at-once product surfaces.

Verdicts:
- PASS
- PASS_WITH_NOTES
- FAIL_OVERLOADED
- NEEDS_TASTE_REVIEW

Flag as overloaded when:
- more than one primary CTA competes above the fold
- too many panels appear on the first screen
- customer-facing first screen shows internal/admin tools
- copy is vague, trendy, or feature-list shaped
- unrelated workflows share one route
- the screen needs explanation before the user can act
- mobile starts inside a giant form/table

Allow:
- rich depth below the first screen
- secondary routes
- drawers or modals for detail
- analytical dashboard density when hierarchy is clear

Sample fail:
```text
FAIL_OVERLOADED: wine list, helper wizard, cellar notes, vendor export, admin edit,
and marketing sections all compete on first load.
```

Sample pass:
```text
PASS_WITH_NOTES: wine list is primary; helper opens from one clear button; cellar notes
are hidden in bottle detail.
```

