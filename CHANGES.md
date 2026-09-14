# What changed and why

A pass over the whole app: real defects first, then one design system across
both sides, then the things that stop it shipping.

---

## 1. The build problem was your machine, not the code

The `flutter_01.log` you sent is not a list of code errors. It is the Dart
analysis server being killed:

```
analysis server exited with code -1073740791
../../runtime/vm/os_thread.cc: 364: error: Could not start thread DartWorker: 22
```

Next to it in the repo were nine `hs_err_pid*.log` files, all saying the same
thing from the JVM side:

```
There is insufficient memory for the Java Runtime Environment to continue.
Native memory allocation (mmap) failed to map 130023424 bytes. Error detail: G1 virtual space
```

Both processes died trying to *reserve* memory. `android/gradle.properties`
asked for a 3 GB Gradle heap; it now asks for 2 GB, which builds this project
comfortably. Close other Gradle daemons, IDE analysis servers and emulators
before a build and the crashes should stop. The 3.6 MB of crash dumps and
replay logs that were committed have been deleted and added to `.gitignore`.

---

## 2. Defects fixed

**A doctor could never open a patient.** The router's role guard treated
anything starting with `/student-` as a student-only route, and
`/student-profile` is the doctor's view of a patient. Every doctor who tapped
a patient got bounced back to their own dashboard. The guard now excludes
doctor-owned routes explicitly.

**The doctor dashboard overflowed on a normal phone.** Header, stats,
emergencies, quick actions, approvals and the day's schedule were laid out in a
fixed `Column` with one `Expanded`, inside a `RefreshIndicator` that had no
scrollable to drive. On a 360×640 screen that yellow-and-black-striped; pull to
refresh did nothing. It is now a sliver list - it scrolls, and refresh works.

**Two dead routes.** `/doctor/student/:id` and `/doctor/student/:studentId`
declared the same path shape twice; only the first was reachable. And
`:studentId?` is not valid go_router syntax, so `/doctor-medical-history`
(without an id) never matched and fell through to the exception handler. Both
are now declared properly.

**The theme lied about itself.** `buildDarkTheme()` built a `Brightness.dark`
`ThemeData` with a `ColorScheme.dark`, filled entirely with *light* colours
(`darkPageBg` was `#F8FAFC`). Every Flutter widget that reads brightness rather
than an explicit colour - dialogs, snack bars, menus, text-selection handles,
keyboard appearance, status-bar icons - picked dark-theme defaults and rendered
light-on-light. There is now one honestly-declared light theme.

**Leaked controllers.** Five `TextEditingController`s in the doctor's
"add lab result" sheet were never disposed; nor were four in the student
profile's bottom sheets, nor the one in the deny-record dialog. Each holds a
listener list and a native text-input connection. All are disposed now, on the
path the sheet actually closes by.

**A realtime channel that was never removed.** The doctor dashboard called
`unsubscribe()`, which leaves the channel registered on the client. It now
calls `removeChannel()`, and debounces the reload so a burst of row changes
causes one refetch instead of ten.

**Appointments showed "Student" instead of a name.** The rows carry only
`student_id`; nothing resolved it. Names are now looked up once per load.

**A dead notification bell.** The student dashboard's bell had `onTap: () {}`.
It opens notifications now - and the notifications screen no longer forces
`/doctor-dashboard` on back, which sent students to the wrong side of the app.

---

## 3. One design system

### Before

| | |
|---|---|
| Blues in use | `#3A86FF`, `#5B8CFF`, `#2563EB`, `#3B82F6` |
| Greens in use | `#22C55E`, `#2ECC71`, `#059669`, `#16A34A`, `#0D9488` |
| Hard-coded hex literals | **415**, across 23 files |
| Doctor bottom nav | hand-rolled, green `#059669`, 3 tabs |
| Student bottom nav | a different widget, blue, 5 tabs |
| Doctor app bars | some solid blue with white text, some white, some none |
| Student screens | headerless off-white pages |
| Empty states | eight different hand-written versions |

### After

- **`lib/theme/app_theme.dart`** - one palette, one type scale, one `ThemeData`.
  Hex literals outside it: **5**, each annotated with why it is an exception
  (a payment provider's trademarked colour, the frozen onboarding gradient, a
  night-mode map canvas, a three-step risk ramp).
- **`lib/widgets/app_ui.dart`** - the component set both dashboards render
  from. Not two look-alikes: the same widgets.
- The doctor dashboard is now structurally the student dashboard: greeting
  header, stat row, hero banner, quick-action grid, sectioned list - same
  widgets, same spacing, same states.
- One `AppBottomNav`. The shells differ by one line: `accent`.
- Doctor app bars inherit from the theme instead of each inventing a look.
- `common_widgets.dart` (866 lines) was imported by nothing - deleted. Seven
  unused Bloom components went with it.

### Accessibility

- **Type.** The old scale bottomed out at **8.5px**. Body copy is now 15px and
  the smallest label is 11px. `main.dart` clamps the OS text scale to 0.85–1.4,
  so a user at 200% gets bigger text without bursting fixed-height cards.
- **Contrast.** `textSecondary` on white is 4.8:1. White on `warning` was
  2.1:1 in the quick-action tiles - those now use `fillAmber` (5.2:1). Status
  colours on the dark snack bar have lightened `*OnDark` variants.
- **Touch targets.** Buttons, icon buttons and nav items are all ≥48×48.
- **Tooltips.** 24 icon-only buttons had no label. All 26 do now.
- **Not colour alone.** Status chips carry a dot as well as a hue.
- **Motion.** The loading skeleton checks `disableAnimations` before it
  animates.

---

## 4. Production readiness

| | Before | After |
|---|---|---|
| iOS camera/mic purpose strings | **missing** - iOS kills the app the moment Agora asks for the camera, and App Review rejects the binary | present, with photo-library and encryption-exemption keys |
| Release signing | debug key | reads `android/key.properties`; warns loudly and falls back to debug if absent |
| `applicationId` | `com.example.telemedicine101` - rejected by the Play Console | `com.somacare.app` |
| Agora ProGuard rules | **missing** with `isMinifyEnabled = true` - R8 strips the JNI entry points, so video calls fail *only in release* | added, along with permission_handler and printing |
| `usesCleartextTraffic` | `true` | `false` - everything is HTTPS |
| `CALL_PHONE` permission | requested but unused (the app opens the dialler with a `tel:` intent, which needs no permission) - a Play Store policy flag | removed; Agora's network/bluetooth permissions added |
| Supabase config | hard-coded | `--dart-define` with the current values as defaults |
| Startup failure | black screen | an explained error screen |
| Release crashes | red error screen | a screen a patient can act on |
| Keystores in `.gitignore` | no | yes |

---

## 5. Tests

`test/widget_test.dart` used to pump `SOMACAREApp()` and look for onboarding
text - it could not pass without a live Supabase session. It now covers the
design system, which needs no backend and runs in CI:

- the theme declares the brightness it actually is
- no body or label style is below 11px
- text colours meet WCAG AA on the card surface
- status colours clear 3:1 on the inverse surface
- buttons are at least 48px tall
- database status strings map to the right tone
- the nav bar labels every destination and reports the selected tab
- the empty state explains itself and its action fires
- three stat cards do not overflow at 360px

---

## 6. How this was verified

`flutter analyze` could not be run where this work was done - the sandbox has
no access to pub.dev or the Flutter SDK download. Two things were done instead.

**A structural checker** (`tools/dart_check.py`) validates bracket balance
across all 63 files, that every `AppColors.*` / `AppSpacing.*` / `AppRadius.*`
member referenced actually exists, that no `const` is applied to a field
reference, and that every file importing a design token has the import. It
found and fixed one real bug: a tooltip inserted into a widget that had no
`tooltip` parameter.

**Validation against your actual SDK.** With read access to
`D:\flutter\packages\flutter\lib\src`, every constructor call in the project - **367 sites** - had its named arguments checked against the real signatures in
Flutter 3.41.2. Zero mismatches. All 191 `Icons.*` names were confirmed to
exist. `TextScaler.clamp`, `SliverList.separated`, `MediaQuery.textScalerOf`,
`InkSparkle.splashFactory`, `DialogThemeData` and `TabBarThemeData` were each
confirmed present with the signatures used.

That is not a substitute for the type checker. Run these first:

```bash
flutter pub get
flutter analyze
flutter test
```
