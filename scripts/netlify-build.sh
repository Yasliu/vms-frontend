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

API_BASE_URL="${API_BASE_URL:-}"

if [ -z "$API_BASE_URL" ]; then
  echo "WARNING: API_BASE_URL is not set. Building frontend without a live backend URL." >&2
  echo "Set API_BASE_URL under Site configuration > Environment variables (e.g. https://your-backend-host) once the backend is ready." >&2
else
  case "$API_BASE_URL" in
    https://*) ;;
    *) echo "ERROR: API_BASE_URL must start with https:// (browsers block http:// calls from an https site)." >&2; exit 1 ;;
  esac
  case "$API_BASE_URL" in
    *@*) echo "ERROR: API_BASE_URL must not contain credentials (user:password@)." >&2; exit 1 ;;
  esac
fi

export PATH="$HOME/flutter-sdk/bin:$PATH"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter ($FLUTTER_VERSION) ..."
  rm -rf "$HOME/flutter-sdk"
  if ! git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter-sdk"; then
    echo "Falling back to Flutter stable branch ..."
    rm -rf "$HOME/flutter-sdk"
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$HOME/flutter-sdk"
  fi
fi

git config --global --add safe.directory "$HOME/flutter-sdk" || true

flutter --version
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"
echo "Built build/web (API_BASE_URL=${API_BASE_URL:-<not set>})"
