#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter}"
ENVIRONMENT="${PARKINSUM_ENV:-prod}"
FIREBASE_PROJECT_ID="${PARKINSUM_FIREBASE_PROJECT_ID:-${FIREBASE_PROJECT_ID:-}}"
RUN_FULL_TESTS="${RUN_FULL_TESTS:-1}"
RELEASE_ID="${RELEASE_ID:-p0_${ENVIRONMENT}_$(date -u +%Y%m%dT%H%M%SZ)}"
DEPLOY_FIRESTORE=0
DEPLOY_HOSTING=0
CREATE_SOURCE_BUNDLE=1

usage() {
  cat <<'USAGE'
Usage:
  PARKINSUM_ENV=dev|stage|prod PARKINSUM_FIREBASE_PROJECT_ID=<project> tool/release_deploy.sh [options]

Options:
  --deploy-firestore  Deploy Firestore rules and indexes after validation.
  --deploy-hosting    Deploy Firebase Hosting after validation. Requires a hosting block in firebase.json.
  --skip-full-tests   Run analyzer, importer smoke, and build, but skip full flutter test.
  --no-source-bundle  Do not create a retained source bundle/checksum.
  -h, --help          Show this help.

Default behavior validates and builds only. It does not deploy.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deploy-firestore)
      DEPLOY_FIRESTORE=1
      ;;
    --deploy-hosting)
      DEPLOY_HOSTING=1
      ;;
    --skip-full-tests)
      RUN_FULL_TESTS=0
      ;;
    --no-source-bundle)
      CREATE_SOURCE_BUNDLE=0
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

case "$ENVIRONMENT" in
  dev|stage|prod)
    ;;
  *)
    echo "PARKINSUM_ENV must be dev, stage, or prod. Got: $ENVIRONMENT" >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"

if [[ ! -x "$FLUTTER_BIN" ]]; then
  echo "Flutter binary is not executable: $FLUTTER_BIN" >&2
  exit 2
fi

if [[ "$DEPLOY_FIRESTORE" -eq 1 || "$DEPLOY_HOSTING" -eq 1 ]]; then
  if [[ -z "$FIREBASE_PROJECT_ID" ]]; then
    echo "FIREBASE_PROJECT_ID is required for deployment." >&2
    exit 2
  fi
fi

expected_project() {
  case "$ENVIRONMENT" in
    dev) echo "parkinsum-companion-dev" ;;
    stage) echo "parkinsum-companion-stage" ;;
    prod) echo "parkinsum-companion" ;;
  esac
}

EXPECTED_PROJECT_ID="$(expected_project)"
if [[ -z "$FIREBASE_PROJECT_ID" ]]; then
  FIREBASE_PROJECT_ID="$EXPECTED_PROJECT_ID"
fi

if [[ "$FIREBASE_PROJECT_ID" != "$EXPECTED_PROJECT_ID" ]]; then
  echo "Project mismatch: PARKINSUM_ENV=$ENVIRONMENT expects $EXPECTED_PROJECT_ID, got $FIREBASE_PROJECT_ID" >&2
  exit 2
fi

if [[ "$ENVIRONMENT" == "prod" && "$DEPLOY_HOSTING" -eq 1 && "${CONFIRM_PROD_HOSTING:-}" != "$FIREBASE_PROJECT_ID" ]]; then
  echo "Prod Hosting deploy requires CONFIRM_PROD_HOSTING=$FIREBASE_PROJECT_ID" >&2
  exit 2
fi

if [[ "$ENVIRONMENT" == "prod" && "$DEPLOY_FIRESTORE" -eq 0 && "$DEPLOY_HOSTING" -eq 0 ]]; then
  echo "Prod dry run: validation/build only. Add deployment flags after sign-off."
fi

echo "ParkinSUM release deploy"
echo "environment=$ENVIRONMENT"
echo "firebase_project=${FIREBASE_PROJECT_ID:-not_set}"
echo "deploy_firestore=$DEPLOY_FIRESTORE"
echo "deploy_hosting=$DEPLOY_HOSTING"

"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" analyze

if [[ "$RUN_FULL_TESTS" -eq 1 ]]; then
  "$FLUTTER_BIN" test
fi

"$FLUTTER_BIN" test test/p0_importers_test.dart --concurrency=1
"$FLUTTER_BIN" build web \
  --dart-define=PARKINSUM_BACKEND=firebase \
  --dart-define=PARKINSUM_ENV="$ENVIRONMENT" \
  --dart-define=PARKINSUM_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID"

ARTIFACT_DIR="build/release_artifacts/$RELEASE_ID"
mkdir -p "$ARTIFACT_DIR"
WEB_BUILD_SHA="$(find build/web -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}')"
SOURCE_BUNDLE=""
SOURCE_BUNDLE_SHA=""

if [[ "$CREATE_SOURCE_BUNDLE" -eq 1 ]]; then
  SOURCE_BUNDLE="$ARTIFACT_DIR/${RELEASE_ID}_source.tar.gz"
  tar \
    --exclude ./build \
    --exclude ./.dart_tool \
    --exclude ./node_modules \
    --exclude ./macos/Pods \
    -czf "$SOURCE_BUNDLE" .
  SOURCE_BUNDLE_SHA="$(shasum -a 256 "$SOURCE_BUNDLE" | awk '{print $1}')"
fi

if [[ "$DEPLOY_FIRESTORE" -eq 1 ]]; then
  firebase deploy --only firestore:rules,firestore:indexes --project "$FIREBASE_PROJECT_ID"
fi

HOSTING_URL="https://${FIREBASE_PROJECT_ID}.web.app"
if [[ "$DEPLOY_HOSTING" -eq 1 ]]; then
  if ! grep -q '"hosting"' firebase.json; then
    echo "firebase.json has no hosting block. Add and review hosting config before deploying hosting." >&2
    exit 2
  fi
  firebase deploy --only hosting --project "$FIREBASE_PROJECT_ID"
fi

MANIFEST_PATH="$(node tool/release_manifest.mjs \
  --release-id "$RELEASE_ID" \
  --env "$ENVIRONMENT" \
  --project "$FIREBASE_PROJECT_ID" \
  --analyzer PASS \
  --firebase-user-binding-test not_run \
  --firestore-rules-contract not_run \
  --web-build PASS \
  --browser-smoke pending \
  --hosting-url "$HOSTING_URL" \
  --web-build-sha256 "$WEB_BUILD_SHA" \
  --source-bundle "$SOURCE_BUNDLE" \
  --source-bundle-sha256 "$SOURCE_BUNDLE_SHA" \
  --source-bundle-id "$RELEASE_ID")"

echo "Release deployment workflow completed."
echo "release_manifest=$MANIFEST_PATH"
echo "hosting_url=$HOSTING_URL"
echo "web_build_sha256=$WEB_BUILD_SHA"
if [[ -n "$SOURCE_BUNDLE" ]]; then
  echo "source_bundle=$SOURCE_BUNDLE"
  echo "source_bundle_sha256=$SOURCE_BUNDLE_SHA"
fi
