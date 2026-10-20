# Guided strength planning

## Product rules

- Sport selection is shared with My Profile. Strength is configured first; running has an explicit handoff and can be deferred independently. A deferred activity keeps its profile/plan draft.
- The strength profile has confirmed v2 answers: experience, goal, locations, equipment and preference. Beginners receive machine-preferred gym suggestions; manual choices remain unrestricted.
- One to six sessions use deterministic composed splits. Four-day plans allow different two-way blocks. Seven sessions and individually named muscle selections are explicit custom arrangements.
- Availability is not frequency. The scheduler searches available days and checks shared muscle groups across the weekly boundary. Two calendar days approximate 48 hours; infeasible availability requires adjustment or an explicitly custom arrangement.
- `StrengthPlanning.candidates` is the reviewed automatic subset. The full catalog stays searchable. Pull-up equipment is corrected in filtered search without rewriting old catalog identities.
- Proposals include warm-up reserve, bilateral/unilateral work, rests and changeovers. Equipment/time gaps must be resolved or explicitly accepted as reduced versions. No weights or max tests are invented.
- Home and gym are setups of the same workout, not duplicate appointments. The existing workout editor and runner remain the editing/tracking surfaces.

## Persistence and compatibility

- `StrengthPlanProposal` is JSON-serializable and remains in setup drafts until activation.
- Profile v2 and planning settings are additive JSON. Existing active plans are not regenerated. Legacy v1 profiles still work for their existing manual plans; automatic generation requires the new confirmed answers.
- Schema 10 adds prescription rest/source and optional per-occurrence workout replacement. Schema 9 and earlier supported backups remain readable. Session snapshots carry rest/source too.
- Activation materializes canonical templates, location setups, exercise slots and prescriptions inside the program transaction. Stable proposal IDs make retries idempotent. A missing exercise aborts the entire transaction.
- Interest repair runs once from active plan components. Later deselection does not delete plans or history.
- Calendar movement preserves occurrence identity. Drop adds to an occupied day. Named move/swap/replace actions remain available; recurring movement is explicit. Started/completed sessions are checked again in storage.

## Verification

Local tests cover split frequencies and recovery, deterministic generation, equipment and time constraints, profile gates, atomic rollback/retry, variant persistence, backup round-trip, drag/drop, serial onboarding and responsive previews.

Android checks use only `tool/test_android_integration.ps1 -DeviceId emulator-5554 -Test plan_onboarding_test`. It verifies the separate `com.example.trainy.integration` package, exercises running-only and generated strength activation with running deferred, and rebuilds the normal APK afterward. Never run a device integration target directly against the production package.

Visual references include Home/week states, actual completed/streak states, calendar, equipment selection and generated-workout review. German/English and large-font layouts are exercised in widget tests.
