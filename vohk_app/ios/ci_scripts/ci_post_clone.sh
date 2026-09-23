#!/bin/sh

set -e

echo "=== Xcode Cloud Flutter setup ==="

# ci_post_clone.sh is located in:
# vohk_app/ios/ci_scripts/
#
# Go two levels up to:
# vohk_app/
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "Flutter project root:"
pwd

# Make absolutely sure we're in the Flutter project.
if [ ! -f "pubspec.yaml" ]; then
    echo "ERROR: pubspec.yaml not found in:"
    pwd
    exit 1
fi

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git \
    --depth 1 \
    -b stable \
    "$HOME/flutter"

export PATH="$PATH:$HOME/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Preparing Flutter for iOS..."
flutter precache --ios

echo "Getting Flutter dependencies..."
flutter pub get

echo "Generating iOS/Xcode configuration..."
flutter build ios --release --no-codesign --config-only

echo "Preparing CocoaPods..."
cd "$PROJECT_ROOT/ios"

if ! command -v pod >/dev/null 2>&1; then
    echo "CocoaPods not found. Installing..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

echo "CocoaPods version:"
pod --version

echo "Installing iOS dependencies..."
pod install

echo "=== Xcode Cloud Flutter setup complete ==="

exit 0
