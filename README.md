# Tactic Goal

Tactic Goal is an isometric, card-driven football puzzle game built with
Flutter and Flame. It includes two worlds with ten BFS-verified levels each,
local star progress, undo/restart controls, procedural sound effects, and
original toy-style game assets.

## Run and verify

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

The solver and Dart-side breadth-first search test are in `test/`. Level JSON
files live in `assets/levels/`; `python3 tools/generate_levels.py` regenerates
them and verifies that each has a solution.

## Mobile builds

Pushing to `main` runs `.github/workflows/build_mobile.yml`. The workflow
publishes an Android release APK and an unsigned iOS IPA as GitHub Actions
artifacts. The iOS output is not installable until it is signed with an Apple
development/distribution certificate and provisioning profile.
