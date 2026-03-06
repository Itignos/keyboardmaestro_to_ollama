#!/bin/bash
# Helper script to package the plugin into a .zip file

PLUGIN_NAME="keyboardmaestro_to_ollama"
ZIP_FILE="${PLUGIN_NAME}.zip"

# Create a clean release folder
echo "Creating release folder: ${PLUGIN_NAME}"
rm -rf "${PLUGIN_NAME}"
mkdir "${PLUGIN_NAME}"

# Copy required files
echo "Copying files..."
cp "Keyboard Maestro Action.plist" "${PLUGIN_NAME}/"
cp Action.sh "${PLUGIN_NAME}/"

# Ensure Action script is executable
chmod +x "${PLUGIN_NAME}/Action.sh"

# Zip the folder
echo "Zipping to ${ZIP_FILE}..."
rm -f "${ZIP_FILE}"
zip -r "${ZIP_FILE}" "${PLUGIN_NAME}"

# Clean up the folder
echo "Cleaning up..."
rm -rf "${PLUGIN_NAME}"

echo "Done! You can now drag ${ZIP_FILE} onto your Keyboard Maestro icon in the macOS Dock to install it."
