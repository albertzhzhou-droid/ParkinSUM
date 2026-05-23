# Project Rules

## Architecture
- Provider-based state management
- Services layer handles persistence
- EntryPage must NOT use context.watch

## Coding Rules
- Do not break existing folder structure
- Do not introduce Firebase
- Keep logic in services / state, not UI

## Debug Requirements
- Always add print logs for critical flows
- Ensure UI interactions are testable

## Build Command
flutter pub get
flutter run

## Test Workflow
- Add meal
- Save meal
- Check dashboard update