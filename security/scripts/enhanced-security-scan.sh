#!/bin/bash

APK_PATH=$1
OUTPUT_DIR=/workspace

echo " Starting enhanced security scan..."

# Static analysis with multiple tools
echo "Running APK analysis..."
apktool d "$APK_PATH" -o "$OUTPUT_DIR/decompiled"

# Check for common vulnerabilities
echo "Checking for security vulnerabilities..."
python3 -c "
import os
import json

vulnerabilities = []

# Check for hardcoded secrets
for root, dirs, files in os.walk('$OUTPUT_DIR/decompiled'):
    for file in files:
        if file.endswith('.smali') or file.endswith('.xml'):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if 'password' in content.lower() or 'api_key' in content.lower():
                        vulnerabilities.append(f'Potential hardcoded secret in {filepath}')
            except:
                pass

# Check permissions
manifest_path = '$OUTPUT_DIR/decompiled/AndroidManifest.xml'
if os.path.exists(manifest_path):
    with open(manifest_path, 'r') as f:
        manifest = f.read()
        if 'android.permission.WRITE_EXTERNAL_STORAGE' in manifest:
            vulnerabilities.append('Uses external storage permission')

# Output results
result = {
    'scan_type': 'enhanced_static',
    'vulnerabilities': vulnerabilities,
    'timestamp': '$(date -Iseconds)'
}

with open('$OUTPUT_DIR/enhanced-security-scan.json', 'w') as f:
    json.dump(result, f, indent=2)

print(f'Found {len(vulnerabilities)} potential security issues')
"

echo "Enhanced security scan complete"
