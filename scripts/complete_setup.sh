#!/bin/bash

echo "🎉 Family Academy Client - Final Setup Steps"
echo "=========================================="
echo ""
echo "1. Installing Flutter packages..."
flutter pub get

echo ""
echo "2. Generating launcher icons..."
flutter pub run flutter_launcher_icons:main

echo ""
echo "3. Running build runner (if needed)..."
flutter packages pub run build_runner build --delete-conflicting-outputs

echo ""
echo "4. Verifying asset structure..."
if [ -d "assets/fonts/Roboto" ] && [ -d "assets/images" ] && [ -d "assets/lottie" ]; then
    echo "✅ Asset structure verified"
else
    echo "❌ Asset structure incomplete"
    exit 1
fi

echo ""
echo "5. Testing Flutter build..."
flutter analyze

echo ""
echo "🎊 Setup complete! You can now run:"
echo "   flutter run"
echo ""
echo "Or build the app:"
echo "   flutter build apk --release"
