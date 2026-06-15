# Task Context: mobile(iOS ) version of commander need to reach parity
Project: mobile commander  |  Task #205  |  Status: done
Worker: palmr-m1  |  Cost: $2.917
Branch: task/205-mobile-ios-version-of-commander-need-to

## Description
a lot of the features in ~/repos/exprimental web UI are not in mobile
please evaluate and add accodringly

what stands out
projects not sowing in dashboard
I don't want a separate Workers options on the menu

## What Was Done
Done. Here's what was accomplished:

**Changes made (commit `401aa48`):**

1. **Projects now show on the dashboard** — Per-project cards with progress bars, task counts, running/failed indicators. Tapping a project navigates to a dedicated ProjectDetailView with filters and search.

2. **Workers tab removed from menu** — Workers section is still visible on the Dashboard (inline), but no longer a standalone tab consuming navigation space.

3. **Reports tab added** — Shows today/week/all-time completion metrics, cost breakdown (today/week/total), per-project stats with progress bars, and a status overview section.

4. **Task creation enhanced** — Now includes project quick-select pills, depends-on field, assign worker picker (populated from live workers), and allow parallel toggle — matching the web UI's capabilities.

5. **Stats grid expanded** — Dashboard now shows 4 stats (Running, Pending, Review, Done) plus an overall progress bar with total cost.

Build verified on iOS Simulator (iPhone 17, iOS 26.4) with zero compilation errors or warnings in the source files.

## Working Directory
/Users/jc/repos/mobile-exprimental

## Test Status: none


