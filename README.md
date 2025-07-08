# android-cuttlefish-gitlab-cicd

## Android DevOps CI-CD PipeLine with CuttleFish and GitLab

### Setting up required permissions in GCP

#### Create Service Account

``` sh
# Set your project ID
export PROJECT_ID="your-gcp-project-id"

# Create service account
gcloud iam service-accounts create cuttlefish-ci \
    --description="Service account for Cuttlefish CI/CD" \
    --display-name="Cuttlefish CI"

# Get the service account email
export SA_EMAIL="cuttlefish-ci@${PROJECT_ID}.iam.gserviceaccount.com"
```

#### Create JSON key

``` sh
gcloud iam service-accounts keys create cuttlefish-ci-key.json \
    --iam-account=${SA_EMAIL}

# Base64 encode for GitLab (Linux)
base64 -w 0 cuttlefish-ci-key.json > gcp-key-base64.txt

# Macos
base64 -b 0 -i cuttlefish-ci-key.json -o gcp-key-base64.txt

# Copy the base64 content
cat gcp-key-base64.txt
```

#### Configure permissions for our IAM

``` sh
# Create custom role with minimal permissions
gcloud iam roles create cuttlefish.ci.minimal \
    --project=$PROJECT_ID \
    --title="Cuttlefish CI Minimal" \
    --description="Minimal permissions for Cuttlefish CI" \
    --permissions="compute.instances.create,compute.instances.delete,compute.instances.get,compute.instances.list,compute.instances.setMetadata,compute.instances.start,compute.instances.stop,compute.instanceGroups.create,compute.instanceGroups.delete,compute.instanceGroups.get,compute.instanceGroups.list,compute.instanceGroupManagers.create,compute.instanceGroupManagers.delete,compute.instanceGroupManagers.get,compute.instanceGroupManagers.list,compute.instanceGroupManagers.update,compute.instanceTemplates.create,compute.instanceTemplates.delete,compute.instanceTemplates.get,compute.instanceTemplates.list"

# Assign the custom role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="projects/${PROJECT_ID}/roles/cuttlefish.ci.minimal"
```

### Android Keystore Setup Guide

#### Step 1: Generate a Debug Keystore

``` sh
# Navigate to your project directory
cd android-cuttlefish-gitlab-cicd

# Generate debug keystore
keytool -genkey -v \
  -keystore debug.keystore \
  -storepass android \
  -alias androiddebugkey \
  -keypass android \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"

# This creates debug.keystore file
```

#### Step 2: Base64 Encode the Keystore

``` sh
# Linux/Mac
base64 -w 0 debug.keystore > keystore-base64.txt

# Windows PowerShell
# [Convert]::ToBase64String([System.IO.File]::ReadAllBytes("debug.keystore")) > keystore-base64.txt

# Copy the content
cat keystore-base64.txt
```

#### Step 3: Your Environment Variables

For your debug keystore, use these values:
KEYSTORE_FILE: [content of keystore-base64.txt]
KEYSTORE_PASSWORD: android
KEY_ALIAS: androiddebugkey
KEY_PASSWORD: android

#### Alternative: Use Existing Debug Keystore

If you have Android Studio installed, you can use the existing debug keystore:

``` sh
# Location of default debug keystore
# Linux/Mac: ~/.android/debug.keystore
# Windows: %USERPROFILE%\.android\debug.keystore

# Copy it to your project
cp ~/.android/debug.keystore ./debug.keystore

# Base64 encode it
base64 -w 0 debug.keystore > keystore-base64.txt
```

#### For Production Apps

If you want to create a production keystore:

``` sh
# Generate production keystore
keytool -genkey -v \
  -keystore release.keystore \
  -storepass YOUR_STRONG_PASSWORD \
  -alias YOUR_KEY_ALIAS \
  -keypass YOUR_KEY_PASSWORD \
  -keyalg RSA \
  -keysize 2048 \
  -validity 25000

# Follow the prompts to enter your information
# CN=Your Name, OU=Your Organization Unit, O=Your Organization, L=Your City, ST=Your State, C=Your Country Code
```

#### Update Your app/build.gradle

Add signing configuration to your app/build.gradle:

``` gradle
android {
    compileSdk 34
    
    defaultConfig {
        applicationId "codepath.demos.helloworlddemo"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
        
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }
    
    signingConfigs {
        debug {
            storeFile file('debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
        release {
            // These will be provided by CI environment variables
            if (project.hasProperty('android.injected.signing.store.file')) {
                storeFile file(project.property('android.injected.signing.store.file'))
                storePassword project.property('android.injected.signing.store.password')
                keyAlias project.property('android.injected.signing.key.alias')
                keyPassword project.property('android.injected.signing.key.password')
            }
        }
    }
    
    buildTypes {
        debug {
            signingConfig signingConfigs.debug
        }
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            signingConfig signingConfigs.release
        }
    }
}
```

### GitLab CI/CD Variables Setup

1. Go to your GitLab project → Settings → CI/CD → Variables
2. Add these variables (click Add Variable for each):

#### Essential Variables (Required)

``` txt
Variable: GCP_SERVICE_ACCOUNT_KEY
Value: [paste the base64 content from gcp-key-base64.txt]
Type: Variable
Protected: ✅ (checked)
Masked: ✅ (checked)

Variable: GCP_PROJECT_ID  
Value: your-gcp-project-id
Type: Variable
Protected: ❌
Masked: ❌

Variable: KEYSTORE_FILE
Value: [paste the base64 content from keystore-base64.txt]
Type: Variable  
Protected: ✅
Masked: ✅

Variable: KEYSTORE_PASSWORD
Value: android
Type: Variable
Protected: ✅
Masked: ✅

Variable: KEY_ALIAS
Value: androiddebugkey
Type: Variable
Protected: ❌
Masked: ❌

Variable: KEY_PASSWORD
Value: android
Type: Variable
Protected: ✅
Masked: ✅
```
