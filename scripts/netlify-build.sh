#!/usr/bin/env bash
# Netlify build for the Flutter web app.
#
# Netlify's build image has no Flutter, so this installs a pinned version, checks the
# production API URL, and builds. Set API_BASE_URL in Netlify:
#   Site configuration > Environment variables > API_BASE_URL = https://your-backend-host
# The URL is public (it ends up in the compiled JavaScript). Never put passwords, tokens
# or database settings in the frontend.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.50.0}"

if [ -z "${API_BASE_URL:-}" ]; then
  echo "ERROR: API_BASE_URL is not set." >&2
  echo "Without it a release build would call the Netlify site itself and every request would fail." >&2
  echo "Set it under Site configuration > Environment variables (for example https://api.example.com)." >&2
  exit 1
fi
case "$API_BASE_URL" in
  https://*) ;;
  *) echo "ERROR: API_BASE_URL must start with https:// (browsers block http:// calls from an https site)." >&2; exit 1 ;;
esac
case "$API_BASE_URL" in
  *@*) echo "ERROR: API_BASE_URL must not contain credentials (user:password@)." >&2; exit 1 ;;
esac

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter $FLUTTER_VERSION ..."
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter-sdk"
  export PATH="$HOME/flutter-sdk/bin:$PATH"
fi

flutter --version
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"
echo "Built build/web for API $API_BASE_URL"
