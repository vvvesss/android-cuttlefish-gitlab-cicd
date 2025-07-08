#!/bin/bash
# security/scripts/dynamic-security-scan.sh

PACKAGE_NAME=$1
echo "🔒 Running dynamic security scan on $PACKAGE_NAME..."

# Basic dynamic tests
adb shell am start -n $PACKAGE_NAME/.HelloWorldActivity
sleep 5

# Check for security issues
echo "Checking for insecure network traffic..."
adb shell netstat > network_connections.txt

echo "✅ Dynamic security scan complete"
