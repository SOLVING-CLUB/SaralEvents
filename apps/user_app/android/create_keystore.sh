#!/bin/bash

echo "========================================"
echo "Android Keystore Generator"
echo "========================================"
echo ""
echo "This script will create a release keystore for your app."
echo ""
echo "IMPORTANT:"
echo "- Keep this keystore file safe! You'll need it for all future updates."
echo "- The SHA1 fingerprint will be different from the one you provided."
echo "- If you need the specific SHA1 (42:C0:05:DB:3D:92:D7:39:A5:DF:25:F8:FD:72:50:4E:FE:C0:A9:1F),"
echo "  you need the original keystore file that generated it."
echo ""

KEYSTORE_NAME="release-key.keystore"
KEYSTORE_PATH="app/$KEYSTORE_NAME"
KEY_ALIAS="release"
VALIDITY_DAYS=10000

echo ""
echo "Creating keystore: $KEYSTORE_PATH"
echo "Key alias: $KEY_ALIAS"
echo "Validity: $VALIDITY_DAYS days (~27 years)"
echo ""

keytool -genkey -v -keystore "$KEYSTORE_PATH" -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity $VALIDITY_DAYS

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "Keystore created successfully!"
    echo "========================================"
    echo ""
    echo "Verifying SHA1 fingerprint..."
    echo ""
    keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$KEY_ALIAS"
    echo ""
    echo "========================================"
    echo "Next steps:"
    echo "1. Copy key.properties.template to key.properties"
    echo "2. Update key.properties with your keystore details"
    echo "3. Build your AAB: flutter build appbundle --release"
    echo "========================================"
else
    echo ""
    echo "ERROR: Failed to create keystore"
    echo "Make sure Java keytool is in your PATH"
fi

