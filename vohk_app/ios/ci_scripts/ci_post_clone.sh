#!/bin/sh

set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

echo "Preparing Flutter..."
flutter precache --ios

echo "Getting Flutter dependencies..."
flutter pub get

echo "Generating iOS/Xcode configuration..."
flutter build ios --release --no-codesign --config-only

echo "Installing CocoaPods..."
HOMEBREW_NO_AUTO_UPDATE=1
brew install cocoapods

echo "Installing iOS dependencies..."
cd ios
pod install

exit 0
