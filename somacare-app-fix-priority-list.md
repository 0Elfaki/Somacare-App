# SomaCare App — Fix Priority List

Critical to least severe. Checked items are done; everything else is open and in the order to tackle it. Two corrections from the original audit are marked where today's closer read of the code changed the finding.

**Working directly against your cloned repo now** (`C:\Users\ALMEGDAD\Downloads\AA\Somacare-App`) via the linked-device connection, not from the partial upload — that's what unblocked the medication-reminder fix below, since the real `data/`/`providers/` layer is there. Fixes land straight in your working tree; nothing further to copy in.

## Tier 0 — Access control (fix first, this is the permission boundary for the whole app)

- [x] ~~`student_login_screen.dart` — unconditional role upsert self-assigns doctor access~~ — **correction:** traced the actual logic and it doesn't hold up. `dbRole` is read fresh from the DB every login; when no profile row exists yet it defaults to `'student'`, and the code hard-blocks (signs the user back out) whenever `dbRole != _role` — so a brand-new account can never log in as Doctor, only Student. There's no path to self-assigned doctor access here. Hardened anyway: the role `upsert` now only fires when `profile == null` (first-ever login), so an existing role can never be rewritten by the client even in principle, and the role tab / school selector are now disabled while `_isLoading` so the selection can't change mid-request.
- [x] `doctor_appointments_screen.dart` — confirmed real: when the doctor-scoped query came back empty it fell through to an unfiltered `.limit(20)` query and displayed every patient's appointments. Removed that fallback entirely (kept the legacy doctor-name lookup, since that's still scoped to the one doctor); also stripped the `debugPrint` trail left in `initState`/`build`/`_buildSimpleList`.
- [x] `doctor_medical_history_management_screen.dart` — confirmed real: `_loadPatients()` correctly computed `studentIds` from the doctor's own appointments but then discarded it and populated the dropdown from every `role == 'student'` profile in the database. Now fetches only the profiles in `studentIds` (`.inFilter('id', studentIds)`).

## Tier 1 — Critical (data integrity, safety, user-facing correctness)

- [x] `messaging_chat_screen.dart` — confirmed real: opened with no `doctorId` (the dashboard's "Message a doctor" quick action passed none), it loaded a fabricated conversation about headaches, an image, and a voice note as if it were real chat history. Removed the demo thread and the fake typed-reply simulation entirely; the screen now shows a "No conversation yet" state prompting the student to pick a doctor from a confirmed appointment, with the fake "Online" presence dot and the video-call action also gated off until a real doctor thread is loaded. Retargeted the dashboard's quick action to `/my-appointments`, where the real per-appointment "Message" button already carries a doctorId.
- [x] `student_profile_screen.dart` — confirmed real: `height`/`weight`/`blood_type`/`blood_pressure` defaulted to 170/70/A+/120-80 whenever missing, indistinguishable from a real reading; the past-appointment badge always used `successSurface`/`primary` regardless of `status`. Vitals now show "Not recorded" in muted italic when absent (BMI is skipped rather than computed from fake height/weight), and the badge is colored from the appointment's actual status (completed/confirmed = success tones, pending = warning, cancelled/rejected/declined = error, anything else = neutral "Unknown"). While in this file: also fixed the white-text-on-white-sheet bug in "Add lab result" (Tier 2 #17) — six `TextFormField`/dropdown styles were hardcoded to `Colors.white` against the sheet's white `AppColors.surface` background, now `AppColors.textPrimary`.
- [x] `my_medications_screen.dart` — unblocked once I got direct access to your actual clone (see note below): `MedicationNotifier.addReminder(medicationId, MedicationReminder)` already existed in `providers/medication_provider.dart`, wired to a real `medication_reminders` insert in `data/medication_repository.dart`, but the screen never called it. "Save Reminder" now calls `ref.read(medicationProvider.notifier).addReminder(...)`, shows a spinner on the button while saving, and reports real success/failure instead of an unconditional success toast.
- [x] `payment_screen.dart` — confirmed real: Pay called `onConfirm()` straight from the payment-method selector with no phone number or card details ever collected. Added a required "+256" mobile-money phone field for MTN/Airtel that gates the Pay button until a plausible number is entered. Left card payment disabled with an explanatory notice rather than either hand-rolling a card form (against the design rules — "use Stripe Elements or equivalent, never custom card input from scratch") or guessing whether a Stripe package is already a project dependency (pubspec.yaml wasn't in the upload). Say the word if you want card enabled and I'll check what's available.
- [x] `my_appointments_screen.dart` — added a two-step confirmation dialog before `_cancelAppointment` fires, matching the org's own destructive-action rule; also stripped the leftover `debugPrint` trail.
- [x] `appointment_detail_screen.dart` — the status dropdown now confirms before applying `cancelled` (the one genuinely destructive transition here); routine transitions (pending → confirmed → completed) stay frictionless rather than adding a modal to every click, which would fight the "speed" principle for doctors.
- [ ] `emergency_screen.dart` — two separate things bundled in the original finding, split apart: (1) **"Use current location" was fake** — it showed a success toast and did nothing else, and since the map above it is a static `BloomMapPlaceholder` there was nowhere to plot a real position anyway. Removed rather than left lying; noted inline that real geolocation needs a location package (e.g. `geolocator`) confirmed in your `pubspec.yaml` plus an actual map surface, neither of which I could verify from this upload — treat as a separate feature, not a one-line fix. (2) **Hardcoded to Uganda** (contacts, first-aid content, phone codes) is still untouched — this is a product-scope call, not a bug: is SomaCare Uganda-only, or does this need to key off the student's actual school/country? Tell me which and I'll do the actual edit.
- [x] ~~`symptom_check_screen.dart` — no persistent AI disclaimer~~ — **correction:** there is one. A permanent warning-styled banner ("AI assistant only. Not a substitute for professional medical advice.") sits above the chat on every load. Original finding was wrong; dropped from the list.

## Tier 2 — High (broken/fake functionality, trust-breaking inconsistency)

- [ ] `doctor_profile_screen.dart` — Notifications/Dark Mode switches hardcoded no-ops; Language/Privacy/Security tiles have empty `onTap`.
- [ ] `main.dart` — single light theme only, so any Dark Mode control anywhere is a dead end.
- [ ] Support email mismatch — `doctor_profile_screen.dart` (`support@somacare.com`) vs. `student_login_screen.dart` (`support@somacare.app`). (The fake phone number and unverifiable "24/7 chat" line next to the .com address were removed today; the two different addresses themselves are still unreconciled.)
- [ ] Dead taps — `my_appointments_screen.dart` card tap, `medical_store_screen.dart` bell, `my_medications_screen.dart` add-icon all "coming soon."
- [ ] `notifications_screen.dart` — marks everything read on load before the user sees what's new; only 2 of 6 documented types navigate on tap.
- [x] ~~`student_profile_screen.dart` — white-on-white text bug in the "Add lab result" sheet~~ — done alongside the Tier 1 vitals fix above.
- [ ] Two competing component libraries (`app_ui.dart` vs. `bloom_components.dart`) plus per-screen hand-rolled styling.
- [ ] `BloomButton` default height 42px, under the app's own 48px touch-target rule.
- [ ] `prescription_writer_screen.dart` — refill stepper buttons are 32x32.
- [ ] `student_login_screen.dart` — "Forgot password?" only shows a contact-support toast; no real reset flow.
- [ ] No signup/account-creation flow anywhere in the app — confirm intentional.
- [x] Purple "AI accent" gradient — `AppColors.accent` recolored from purple `#7C3AED` to brand maroon; the symptom checker's icon badges, send button, chat bubbles, and dashboard hero card no longer blend two unrelated hues.
- [x] Onboarding's indigo gradient hero + decorative glow rings — removed, flat maroon background now.
- [x] Fake support phone number + unverifiable "24/7 chat" claim — removed from the doctor help dialog.
- [x] Emoji used as inline icons — removed from all 5 spots (doctor profile snackbar/dialog, emergency-booking snackbar, school-selection failure snackbar, AI assistant greeting/error).

## Tier 3 — Medium (consistency, validation, navigation)

- [ ] Raw exception text shown to users instead of `userFriendlyErrorMessage()` in 7 screens, plus the `on AuthException` branch in `student_login_screen.dart`.
- [ ] Inconsistent deny-reason validation between `doctor_dashboard_screen.dart` (5+ chars enforced) and `doctor_medical_history_management_screen.dart` (near-empty accepted).
- [ ] Vitals entry: proper pickers on student `profile_screen.dart`, free-text on doctor `encounter_form_screen.dart` for the same data.
- [ ] Currency mismatch — UGX vs. `$`.
- [ ] No booking-conflict check in `book_appointment_screen.dart`.
- [ ] `DoctorShell` bottom nav defaults to "Home" on `/doctor-finances` and `/doctor-medical-history`.
- [ ] `appointment_detail_screen.dart` forces back-navigation to `/doctor-dashboard` regardless of entry point.
- [ ] No post-call workflow prompt in `doctor_consult_screen.dart`.
- [ ] `consult_screen.dart` — shared static fallback channel name `'consultation'`.
- [ ] `encounter_form_screen.dart` — no discard-changes guard.
- [ ] `prescription_writer_screen.dart` — no review/confirm step before submit.
- [ ] `student_login_screen.dart` — doctor "License / Doctor ID" field uses an email keyboard.
- [ ] `school_selection_screen.dart` — load-failure is a transient snackbar only, no retry affordance, no "school not listed" escape hatch.
- [ ] Login form has no `Form`/validators (error-border styling exists but is never triggered), doesn't lock fields or the role switcher during an in-flight request, `/doctor-login` only shows the Doctor tab when reached via Role Selection's `extra` (not from the URL itself), no keyboard submit/autofill hints, password-toggle and "Forgot password?" tap targets are under the 48px minimum.

## Tier 4 — Low / polish

- [ ] Hardcoded raw `Color(0x…)` values outside `AppColors` in `student_profile_screen.dart` and `doctor_medical_history_management_screen.dart`.
- [ ] Leftover `debugPrint` / raw row dumps in `doctor_appointments_screen.dart`, `my_appointments_screen.dart`.
- [ ] "Version 2.0.0 2026" typo in `doctor_profile_screen.dart`.
- [ ] Radius drift within `student_profile_screen.dart` (12/14/20px in one view).
- [ ] No search on the doctor's patient list; no doctor bio/photo/ratings shown when booking.
- [ ] `onboarding_screen.dart` — "Skip" appears twice, redundant.
- [ ] No persisted "has seen onboarding" flag.
- [ ] Redundant border + shadow on low-emphasis elements (41 `boxShadow` uses across 15 files; the symptom-checker suggestion chip is the clearest example) — really the same job as the app_ui/Bloom consolidation above, not a separate pass.
- [ ] The bare `—` used as an empty-value placeholder glyph (`app_ui.dart`, `profile_screen.dart`, `encounter_form_screen.dart`) — left alone during the em-dash cleanup since it's a different convention than em-dash-as-punctuation; flag if you want it gone too.
- [x] Inconsistent emoji usage — done, see Tier 2.

---

**Note on the device link:** `device_bash` is unavailable this session, so every fix goes through stage, edit, commit rather than editing in place on your machine directly. Files are grouped per commit to keep that efficient.

Say go on Tier 0 and I'll start there.
