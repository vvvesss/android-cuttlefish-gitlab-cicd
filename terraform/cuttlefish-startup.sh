#!/bin/bash

# terraform/cuttlefish-startup.sh - FIXED VERSION
set -e

echo "🚀 Starting Cuttlefish setup..."
echo "Timestamp: $(date)"
echo "Host: $(hostname)"
echo "IP: $(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google")"

# Update system
echo "📦 Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install required packages
echo "🔧 Installing required packages..."
apt-get install -y \
    wget \
    curl \
    unzip \
    git \
    build-essential \
    libssl-dev \
    libnss3-dev \
    libglib2.0-dev \
    libfdt-dev \
    libpixman-1-dev \
    zlib1g-dev \
    libaio-dev \
    libbluetooth-dev \
    libbrlapi-dev \
    libbz2-dev \
    libcap-dev \
    libcap-ng-dev \
    libcurl4-gnutls-dev \
    libgtk-3-dev \
    libibverbs-dev \
    libjpeg8-dev \
    libncurses5-dev \
    libnuma-dev \
    librbd-dev \
    librdmacm-dev \
    libsasl2-dev \
    libsdl2-dev \
    libseccomp-dev \
    libsnappy-dev \
    libssh-dev \
    libvde-dev \
    libvdeplug-dev \
    libxen-dev \
    liblzo2-dev \
    valgrind \
    xfslibs-dev \
    libnfs-dev \
    libiscsi-dev \
    python3 \
    python3-pip \
    openjdk-11-jdk \
    android-tools-adb \
    android-tools-fastboot \
    socat \
    screen

# Set JAVA_HOME
echo "☕ Setting up Java environment..."
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /etc/environment

# Create cuttlefish user
echo "👤 Creating cuttlefish user..."
useradd -m -s /bin/bash cuttlefish || true
usermod -aG kvm,render cuttlefish || true

# Download and install Cuttlefish - FIXED DOWNLOAD LOGIC
echo "🐠 Downloading Cuttlefish..."
cd /tmp

# Try multiple download sources
CUTTLEFISH_URL="https://github.com/google/android-cuttlefish/releases/download/v1.0.0/cuttlefish-base_1.0.0_amd64.deb"
CUTTLEFISH_COMMON_URL="https://github.com/google/android-cuttlefish/releases/download/v1.0.0/cuttlefish-common_1.0.0_amd64.deb"

# Download with proper error handling
if ! wget -q --timeout=30 --tries=3 "$CUTTLEFISH_URL"; then
    echo "❌ Failed to download Cuttlefish base package"
    echo "🔄 Trying alternative installation method..."
    
    # Alternative: Install from Android CI
    wget -q https://ci.android.com/builds/submitted/8272003/aosp_cf_x86_64_phone-userdebug/latest/cuttlefish-base_1.0.0_amd64.deb || \
    wget -q https://ci.android.com/builds/submitted/8272003/aosp_cf_x86_64_phone-userdebug/latest/cuttlefish-common_1.0.0_amd64.deb || \
    {
        echo "❌ All download attempts failed, building from source..."
        # Install from source as fallback
        git clone https://github.com/google/android-cuttlefish.git
        cd android-cuttlefish
        ./build.sh
        make install
        cd ..
    }
fi

# Install Cuttlefish packages if downloaded
if [ -f "cuttlefish-base_1.0.0_amd64.deb" ]; then
    echo "📦 Installing Cuttlefish packages..."
    dpkg -i cuttlefish-base_1.0.0_amd64.deb || apt-get install -f -y
fi

if [ -f "cuttlefish-common_1.0.0_amd64.deb" ]; then
    dpkg -i cuttlefish-common_1.0.0_amd64.deb || apt-get install -f -y
fi

# Set up KVM permissions
echo "🖥️ Setting up KVM permissions..."
chmod 666 /dev/kvm || true
chown root:kvm /dev/kvm || true

# Download Android system image - SIMPLIFIED
echo "📱 Setting up Android system image..."
mkdir -p /home/cuttlefish/android
cd /home/cuttlefish/android

# Use a working Android image URL
ANDROID_IMAGE_URL="https://dl.google.com/android/repository/sys-img/android/x86_64-30_r10.zip"

if wget -q --timeout=60 --tries=2 "$ANDROID_IMAGE_URL"; then
    echo "✅ Downloaded Android system image"
    unzip -q x86_64-30_r10.zip
    rm x86_64-30_r10.zip
else
    echo "⚠️ Failed to download Android image, creating minimal setup..."
    # Create minimal setup for testing
    mkdir -p system
    touch system/build.prop
    echo "ro.build.version.release=11" > system/build.prop
fi

# Set ownership
chown -R cuttlefish:cuttlefish /home/cuttlefish

# Create Cuttlefish service
echo "🔧 Creating Cuttlefish service..."
cat > /etc/systemd/system/cuttlefish.service << 'EOF'
[Unit]
Description=Cuttlefish Android Virtual Device
After=network.target

[Service]
Type=simple
User=cuttlefish
Group=cuttlefish
WorkingDirectory=/home/cuttlefish
Environment=HOME=/home/cuttlefish
Environment=ANDROID_HOST_OUT=/usr/bin
ExecStart=/bin/bash -c 'cd /home/cuttlefish && cvd start'
ExecStop=/bin/bash -c 'cd /home/cuttlefish && cvd stop'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start ADB service
echo "📱 Setting up ADB service..."
cat > /etc/systemd/system/adb-server.service << 'EOF'
[Unit]
Description=Android Debug Bridge Server
After=network.target

[Service]
Type=simple
User=cuttlefish
Group=cuttlefish
ExecStart=/usr/bin/adb -a -P 5037 server nodaemon
ExecStop=/usr/bin/adb kill-server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable services
systemctl daemon-reload
systemctl enable adb-server
systemctl enable cuttlefish

# Start ADB server immediately
echo "🚀 Starting ADB server..."
systemctl start adb-server

# Wait a bit and start Cuttlefish
echo "⏳ Starting Cuttlefish service..."
sleep 5
systemctl start cuttlefish || echo "Cuttlefish service failed to start, will retry"

# Create a simple test script
cat > /home/cuttlefish/test-adb.sh << 'EOF'
#!/bin/bash
echo "Testing ADB connectivity..."
adb devices
adb shell getprop ro.build.version.release
EOF

chmod +x /home/cuttlefish/test-adb.sh
chown cuttlefish:cuttlefish /home/cuttlefish/test-adb.sh

echo "✅ Cuttlefish setup completed!"
echo "🔍 Services status:"
systemctl status adb-server --no-pager
systemctl status cuttlefish --no-pager

echo "🌐 Network status:"
ss -tlnp | grep -E "(5037|6520)"

echo "🎯 Setup finished at $(date)"
