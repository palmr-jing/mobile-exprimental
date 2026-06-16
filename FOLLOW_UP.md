# Follow-Up

**What was done**: Applied ease-of-use polish to the Mobile Commander iOS app (feedback doc section 5). Added a first-run coaching hint for new Owner-mode users, increased tap target sizes across the app, replaced terse empty states with descriptive ones, and migrated all views from deprecated NavigationView to NavigationStack.

**What needs review**:
- Verify the first-run hint overlay appears on fresh install and dismisses cleanly on tap
- Check that the hint does NOT reappear after dismissal (persisted via `@AppStorage("hasSeenOwnerHint")`)
- Confirm filter chips, template cards, and action buttons feel easy to hit on an actual device (not just simulator)
- Test NavigationStack transitions in both Developer and Owner modes — especially the "See All" link on the Dashboard and TaskDetailView drill-in
- Verify the dictation hint in OwnerRequestView's TextEditor doesn't overlap typed text

**Action items**:
- Run the app on a physical iPhone to confirm tap target sizing feels right in-hand
- The `symbolEffect(.pulse)` on the first-run hint mic icon requires iOS 17+ (already the deployment target, but confirm it renders on older hardware)
- Server-side humanized task titles from Emma (mentioned in the feedback doc as a follow-up) are out of scope here and still needed for Owner mode to stop showing raw dev jargon

**Files changed**:
- `Sources/Design/DesignSystem.swift` — Added `EmptyStateView` and `FirstRunHintView` shared components; increased StatusBadge padding from 3pt to 5pt vertical
- `Sources/Views/Owner/OwnerHomeView.swift` — Added first-run hint overlay with `@AppStorage` persistence; renamed status labels to plain language ("Working on", "Done today", "Needs you" / "All good"); improved empty state for "Recently Completed"
- `Sources/Views/Owner/OwnerRequestView.swift` — NavigationView to NavigationStack; increased template card icon (28 to 32pt) and padding (xl to xxl); added dictation mic hint on TextEditor
- `Sources/Views/Owner/OwnerStatusView.swift` — NavigationView to NavigationStack; added empty state when no tasks exist; increased task row vertical padding (4pt to 8pt)
- `Sources/Views/Developer/DashboardView.swift` — NavigationView to NavigationStack; replaced "No workers connected" one-liner with a descriptive card
- `Sources/Views/Developer/TaskListView.swift` — NavigationView to NavigationStack; filter chips enlarged (6pt to 10pt vertical, DS.Typography.small to .caption); empty state now distinguishes "no tasks" from "no matching filter"
- `Sources/Views/Developer/TaskDetailView.swift` — Action buttons increased from 10pt to 14pt vertical padding; chat send button given 44x44pt frame; output/result empty states made descriptive
- `Sources/Views/Developer/WorkersView.swift` — NavigationView to NavigationStack; empty state uses shared EmptyStateView; hides summary card when no workers
- `Sources/Views/Developer/CreateTaskView.swift` — NavigationView to NavigationStack
- `Sources/Views/Developer/SettingsView.swift` — NavigationView to NavigationStack
- `Sources/Views/Shared/ModeSwitcher.swift` — NavigationView to NavigationStack
