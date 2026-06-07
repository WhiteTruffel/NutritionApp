#!/bin/bash

cd "$(dirname "$0")"

# Build the NutritionApp
xcodebuild -scheme NutritionApp -destination "platform=iOS Simulator,name=iPhone 15 Pro" -derivedDataPath ./DerivedData build

echo "Build complete!"
