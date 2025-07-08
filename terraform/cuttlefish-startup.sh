#!/bin/bash
# terraform/cuttlefish-startup.sh - Startup script for Cuttlefish instances

set -e

echo "🐠 Starting Cuttlefish setup..."

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    git \
    wget \
    unzip \
    python3 \
    python3-pip \
    android-tools-adb \
    android-tools-fastboot \
    qemu-kvm \
    libvirt-clients \
    libvirt-daemon-system \
    cpu-checker \
    bridge-utils \
    dnsmasq \
    curl

# Enable KVM
modprobe kvm_intel || modprobe kvm_amd || echo "KVM modules already loaded"

# Create cuttlefish user
useradd -m -s /bin/bash cuttlefish || echo "User already exists"
usermod -aG kvm,libvirt cuttlefish

# Download and install Cuttlefish
cd /home/cuttlefish
wget -O cuttlefish-base.tar.gz https://storage.googleapis.com/android-build-repo/cuttlefish-bins/latest/cuttlefish-base.tar.gz || \
curl -L -o cuttlefish-base.tar.gz https://github.com/google/android-cuttlefish/releases/download/latest/cuttlefish-base.tar.gz

tar -xzf cuttlefish-base.tar.gz -C /home/cuttlefish/

# Download Android system image (AOSP)
mkdir -p /home/cuttlefish/android-images
cd /home/cuttlefish/android-images

# Use a stable AOSP build
wget https://dl.google.com/android/cuttlefish/aosp_cf_x86_64_phone-img-eng.zip || \
wget https://storage.googleapis.com/android-build-repo/cuttlefish-builds/aosp-master/8692940/aosp_cf_x86_64_phone-img-8692940.zip

# Extract the image
unzip -o *.zip

# Set permissions
chown -R cuttlefish:cuttlefish /home/cuttlefish

# Create systemd service for Cuttlefish
cat > /etc/systemd/system/cuttlefish.service << 'EOF'
[Unit]
Description=Android Cuttlefish Virtual Device
After=network.target

[Service]
Type=forking
User=cuttlefish
Group=cuttlefish
WorkingDirectory=/home/cuttlefish/android-images
ExecStart=/usr/bin/launch_cvd
ExecStop=/usr/bin/stop_cvd
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable cuttlefish
systemctl start cuttlefish

# Wait for Cuttlefish to be ready
sleep 30

# Create a simple health check script
cat > /home/cuttlefish/health-check.sh << 'EOF'
#!/bin/bash
# Simple health check for Cuttlefish
if adb devices | grep -q "127.0.0.1:6520"; then
    echo "Cuttlefish is healthy"
    exit 0
else
    echo "Cuttlefish is not responding"
    exit 1
fi
EOF

chmod +x /home/cuttlefish/health-check.sh

echo "✅ Cuttlefish setup complete!"
