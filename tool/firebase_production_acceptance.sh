#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
ENVIRONMENT="${PARKINSUM_ENV:-prod}"
FIREBASE_PROJECT_ID="${PARKINSUM_FIREBASE_PROJECT_ID:-${FIREBASE_PROJECT_ID:-parkinsum-companion}}"
RUN_FULL_TESTS="${RUN_FULL_TESTS:-0}"
RELEASE_ID="${RELEASE_ID:-p0_${ENVIRONMENT}_$(date -u +%Y%m%dT%H%M%SZ)}"

usage() {
  cat <<'USAGE'
Usage:
  PARKINSUM_ENV=prod PARKINSUM_FIREBASE_PROJECT_ID=<project> tool/firebase_production_acceptance.sh [options]

Options:
  --full-tests       Run the full Flutter test suite in addition to Firebase-focused checks.
  -h, --help         Show this help.

This script performs local/static production acceptance checks only. It does not
deploy rules, grant claims, export data, delete data, or write production user
records.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full-tests)
      RUN_FULL_TESTS=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$ROOT_DIR"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1 && [[ ! -x "$FLUTTER_BIN" ]]; then
  echo "Flutter binary is not available: $FLUTTER_BIN" >&2
  exit 2
fi

echo "Firebase production acceptance preflight"
echo "environment=$ENVIRONMENT"
echo "firebase_project=${FIREBASE_PROJECT_ID:-not_set}"
echo "full_tests=$RUN_FULL_TESTS"

"$FLUTTER_BIN" analyze
"$FLUTTER_BIN" test test/firebase_user_binding_test.dart
node tool/firestore_rules_contract_check.mjs

if [[ "$RUN_FULL_TESTS" -eq 1 ]]; then
  "$FLUTTER_BIN" test
fi

"$FLUTTER_BIN" build web \
  --dart-define=PARKINSUM_BACKEND=firebase \
  --dart-define=PARKINSUM_ENV="$ENVIRONMENT" \
  --dart-define=PARKINSUM_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID"

MANIFEST_PATH="$(node tool/release_manifest.mjs \
  --release-id "$RELEASE_ID" \
  --env "$ENVIRONMENT" \
  --project "$FIREBASE_PROJECT_ID" \
  --analyzer PASS \
  --firebase-user-binding-test PASS \
  --firestore-rules-contract PASS \
  --web-build PASS \
  --browser-smoke pending)"

echo "Local/static Firebase production acceptance preflight completed."
echo "release_manifest=$MANIFEST_PATH"
echo "Manual live checks still required: stage/prod rule probes, claims grant/removal verification, backup export, monitoring review, and browser smoke."
