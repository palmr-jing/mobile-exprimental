# Firestore rules drift — shared project `fir-web-codelab-8ace9` (#1069)

The Videos tab's "Missing or insufficient permissions" was **not an app bug**. On
2026-07-19T03:43Z another repo (the coach / PT / fit app) deployed its own
`firestore.rules` to this shared Firebase project. A rules deploy replaces the
**entire** ruleset, so 23 collection blocks that only the commander ruleset knew
about vanished, and every read of them fell through to deny.

This is the same cross-repo clobber that previously bit `storage.rules`.

## Restored (deployed 2026-07-19T12:38Z, ruleset `21a55a79-63ff-4ef9-9276-46d5b7d5f85c`)

Deployed ruleset = **live verbatim + only the blocks live was missing**. It is a
strict superset of what was live, so it cannot regress the coach/PT app.

Rollback: re-release ruleset `1f52c311-f185-4b16-ba91-36ead17f9b56`.

Blocks restored: mirror_sessions, mirrors_sessions, mirrors_allowed_users,
wallcam_highlights, experimental_videos, released_recordings, dan_3d_map_requests,
dan_analysis_requests, dan_3d_map, dan_analysis, issue_reports, pool_analyses,
commander_class_deliveries, **commander_videos**, manage_allowed_users,
commander_presence, commander_channels, commander_weekly_summaries,
commander_project_members, test_runs, orrat_calls, orrat_menu, orrat_settings
(+ helper functions `isAdminUser`, `mirrorsAllowed`).

## STILL UNRECONCILED — needs a human decision

102 collections exist in both rulesets; 86 are identical and **16 differ**. I did
NOT touch these, because neither side is uniformly correct:

- For `commander_*`, the repo copy is newer (e.g. `commander_tasks` in the repo has
  project-level write protection via `canAccessProject`/`taskPathAllowed`; the live
  copy does not — so **that protection is currently NOT enforced in production**).
- For `coach_users` / `coach_schedule_subscriptions`, **live is newer** — the coach
  repo just deployed them. Taking the repo copy would regress that app.

Picking a winner per block needs someone who knows both apps' intent.

## Root cause to fix properly

`~/repos/experimental/commander/firestore.rules` calls itself the source of truth
"covering ALL palmr apps", but it does not contain the coach/PT/fit blocks
(`coach_*`, `pt_*`, `fit_*`, `scan_results`, `ota_scan_results`, `palmr_preorders`,
`auto_funding_requests`). So the next deploy from that repo re-breaks the iOS app,
and the next deploy from the coach repo re-breaks it again. Until one ruleset is
genuinely the union, these two repos will keep clobbering each other.

## The 16 divergent blocks

### coach_users

**commander repo (source of truth):**
```
    match /coach_users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    match /coach_users/{uid}/{collection}/{doc} {
      allow read, write: if request.auth != null
        && collection != 'meta'
        && coachUsersLinkedCoach(uid);
    }
```

**live before restore (deployed by the other repo):**
```
    match /coach_users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
```

---

### coach_schedule_subscriptions

**commander repo (source of truth):**
```
    match /coach_schedule_subscriptions/{uid} {
      allow read: if request.auth != null && (request.auth.uid == uid || isAdminUser());
      allow write: if request.auth != null && request.auth.uid == uid;
    }
```

**live before restore (deployed by the other repo):**
```
    match /coach_schedule_subscriptions/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
```

---

### commander_user_projects

**commander repo (source of truth):**
```
    match /commander_user_projects/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && (
        request.auth.uid == uid || isAdminUser()
      );
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_user_projects/{uid} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_allowed_users

**commander repo (source of truth):**
```
    match /commander_allowed_users/{docId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_allowed_users/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_tasks

**commander repo (source of truth):**
```
    match /commander_tasks/{taskId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && canAccessProject(request.resource.data.project)
        && taskPathAllowed(request.resource.data.project, request.resource.data.path);
      // Path is only re-validated when it actually changes, so non-admins can
      // still edit other fields on an admin-created override task.
      allow update: if request.auth != null &&
        canAccessProject(resource.data.project) &&
        canAccessProject(request.resource.data.project) &&
        (request.resource.data.path == resource.data.path
         || taskPathAllowed(request.resource.data.project, request.resource.data.path));
      allow delete: if request.auth != null && canAccessProject(resource.data.project);
    }
    match /commander_tasks/{taskId}/output/{chunkId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
        canAccessProject(get(/databases/$(database)/documents/commander_tasks/$(taskId)).data.project);
    }
    match /commander_tasks/{taskId}/chat/{msgId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
        canAccessProject(get(/databases/$(database)/documents/commander_tasks/$(taskId)).data.project);
    }
    match /commander_tasks/{taskId}/input/{inputId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
        canAccessProject(get(/databases/$(database)/documents/commander_tasks/$(taskId)).data.project);
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_tasks/{taskId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
    match /commander_tasks/{taskId}/output/{chunkId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
    match /commander_tasks/{taskId}/chat/{msgId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_workers

**commander repo (source of truth):**
```
    match /commander_workers/{workerId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_workers/{workerId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_notifications

**commander repo (source of truth):**
```
    match /commander_notifications/{notifId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_notifications/{notifId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_settings

**commander repo (source of truth):**
```
    match /commander_settings/{docId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_settings/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_user_drive

**commander repo (source of truth):**
```
    match /commander_user_drive/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow write: if request.auth != null && request.auth.uid == uid;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_user_drive/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_user_drive_pending

**commander repo (source of truth):**
```
    match /commander_user_drive_pending/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_user_drive_pending/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_repo_registry

**commander repo (source of truth):**
```
    match /commander_repo_registry/{repoName} {
      allow read: if request.auth != null;
      // The registry is the source of truth for each project's working dir
      // (taskPathAllowed validates task paths against it), so non-admins must not
      // be able to repoint it. Workers populate it via the admin SDK (bypass rules);
      // the UI only reads it. Non-admins may update non-path fields; create/delete
      // and any path change require admin.
      allow create: if request.auth != null && isAdminUser();
      allow update: if request.auth != null && (
        isAdminUser() || request.resource.data.path == resource.data.path
      );
      allow delete: if request.auth != null && isAdminUser();
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_repo_registry/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_pomodoro

**commander repo (source of truth):**
```
    match /commander_pomodoro/{docId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_pomodoro/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_activity

**commander repo (source of truth):**
```
    match /commander_activity/{activityId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_activity/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_notes

**commander repo (source of truth):**
```
    match /commander_notes/{noteId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_notes/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_inbox_requests

**commander repo (source of truth):**
```
    match /commander_inbox_requests/{requestId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_inbox_requests/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
    match /commander_inbox_requests/{docId}/input/{chunkId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```

---

### commander_project_tags

**commander repo (source of truth):**
```
    match /commander_project_tags/{docId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
```

**live before restore (deployed by the other repo):**
```
    match /commander_project_tags/{docId} {
      allow read: if request.auth != null;
      allow write: if true;
    }
```
