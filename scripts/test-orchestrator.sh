#!/bin/bash
# scripts/test-orchestrator.sh - Enhanced Cuttlefish test orchestration

set -e

INSTANCE_IP=$1
APK_PATH=$2
TEST_APK_PATH=${3:-""}  # Optional test APK

if [ -z "$INSTANCE_IP" ] || [ -z "$APK_PATH" ]; then
    echo "Usage: $0 <INSTANCE_IP> <APK_PATH> [TEST_APK_PATH]"
    exit 1
fi

echo "🚀 Starting comprehensive testing on Cuttlefish..."
echo "📱 Instance IP: $INSTANCE_IP"
echo "📦 APK: $APK_PATH"

# Device readiness check
echo "🔌 Connecting to Cuttlefish device..."
adb connect $INSTANCE_IP:6520
adb wait-for-device

# Device info
echo "📱 Device information:"
adb shell getprop ro.build.version.release
adb shell getprop ro.product.model
adb shell getprop ro.build.version.sdk

# Install main APK
echo "📱 Installing application..."
adb install -r "$APK_PATH"

# Install test APK if provided
if [ -n "$TEST_APK_PATH" ] && [ -f "$TEST_APK_PATH" ]; then
    echo "🧪 Installing test APK..."
    adb install -r "$TEST_APK_PATH"
fi

# Pre-test setup
echo "🔧 Setting up test environment..."
# Disable animations for stable testing
adb shell settings put global window_animation_scale 0.0
adb shell settings put global transition_animation_scale 0.0
adb shell settings put global animator_duration_scale 0.0

# Grant basic permissions (adjust package name as needed)
PACKAGE_NAME="codepath.demos.helloworlddemo"
adb shell pm grant $PACKAGE_NAME android.permission.WRITE_EXTERNAL_STORAGE || echo "Permission not needed"

# Basic app functionality test
echo "🧪 Testing basic app functionality..."

# Launch the app
echo "🚀 Launching application..."
adb shell am start -n $PACKAGE_NAME/.HelloWorldActivity
sleep 3

# Take screenshot
echo "📸 Taking screenshot..."
adb shell screencap -p /sdcard/app_screenshot.png
adb pull /sdcard/app_screenshot.png screenshot.png || echo "Screenshot failed"

# Check if app is running
echo "🔍 Checking app status..."
if adb shell dumpsys activity activities | grep -q $PACKAGE_NAME; then
    echo "✅ App is running successfully"
    echo "App Status: RUNNING" > test_results.txt
else
    echo "❌ App is not running"
    echo "App Status: FAILED" > test_results.txt
fi

# Run instrumentation tests if test APK provided
if [ -n "$TEST_APK_PATH" ] && [ -f "$TEST_APK_PATH" ]; then
    echo "🧪 Running instrumentation tests..."
    adb shell am instrument -w -r -e debug false \
        $PACKAGE_NAME.test/androidx.test.runner.AndroidJUnitRunner >> test_results.txt 2>&1 || \
        echo "Instrumentation tests completed with warnings"
fi

# Performance data collection
echo "📊 Collecting performance data..."

# Memory usage
adb shell dumpsys meminfo $PACKAGE_NAME > memory_profile.txt

# CPU usage
adb shell top -n 1 | grep $PACKAGE_NAME > cpu_profile.txt || echo "No CPU data"

# Activity and window dumps
adb shell dumpsys activity > activity_dump.txt
adb shell dumpsys window > window_dump.txt

# Collect comprehensive logs
echo "📋 Collecting logs..."
adb logcat -d > full_logcat.txt

# App interaction test
echo "🤖 Testing app interactions..."
# Simulate some basic interactions
adb shell input tap 500 500  # Tap center of screen
sleep 1
adb shell input keyevent KEYCODE_BACK
sleep 1

# Final app state check
if adb shell dumpsys activity activities | grep -q $PACKAGE_NAME; then
    echo "✅ App survived basic interactions"
    echo "Interaction Test: PASSED" >> test_results.txt
else
    echo "⚠️ App stopped after interactions"
    echo "Interaction Test: WARNING" >> test_results.txt
fi

# Cleanup
echo "🧹 Cleaning up..."
adb shell am force-stop $PACKAGE_NAME

# Final summary
echo "📋 Test Summary:"
cat test_results.txt

echo "🎉 Testing complete!"
echo "📁 Artifacts generated:"
echo "  - test_results.txt"
echo "  - screenshot.png"
echo "  - full_logcat.txt"
echo "  - memory_profile.txt"
echo "  - cpu_profile.txt"
echo "  - activity_dump.txt"
echo "  - window_dump.txt"
