#!/bin/bash

set -e

INSTANCE_IP=$1
APK_PATH=$2
TEST_APK_PATH=$3

echo "Starting comprehensive testing on Cuttlefish..."

# Device readiness check
adb connect $INSTANCE_IP:6520
adb wait-for-device

# Install apps
echo "Installing applications..."
adb install -r $APK_PATH
adb install -r $TEST_APK_PATH

# Pre-test setup
echo "Setting up test environment..."
adb shell settings put global window_animation_scale 0.0
adb shell settings put global transition_animation_scale 0.0
adb shell settings put global animator_duration_scale 0.0

# Grant permissions
adb shell pm grant com.example.weatherdash android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.example.weatherdash android.permission.ACCESS_COARSE_LOCATION

# Network simulation
echo "Simulating network conditions..."
adb shell cmd connectivity airplane-mode enable
sleep 2
adb shell cmd connectivity airplane-mode disable

# Run tests with retry logic
echo "Running instrumentation tests..."
for i in {1..3}; do
    if adb shell am instrument -w -r -e debug false \
       com.example.weatherdash.test/androidx.test.runner.AndroidJUnitRunner; then
        echo "✅ Tests passed on attempt $i"
        break
    else
        echo "❌ Test attempt $i failed, retrying..."
        sleep 5
    fi
done

# Collect comprehensive logs
echo "Collecting diagnostics..."
adb logcat -d > full_logcat.txt
adb shell dumpsys activity > activity_dump.txt
adb shell dumpsys window > window_dump.txt

echo "🎉 Testing complete!"
