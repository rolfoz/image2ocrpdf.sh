#!/bin/bash

# --- Function to check and install a package ---
install_package() {
    local package_name=$1
    if ! command -v "$package_name" &> /dev/null; then
        echo "🚨 The required tool '$package_name' is not installed."
        echo "Attempting to install '$package_name' using apt. This requires sudo."
        # Use || true to prevent the script from exiting if the update/install fails prematurely
        sudo apt update || true
        sudo apt install -y "$package_name"
        if [ $? -ne 0 ]; then
            echo "❌ Failed to install '$package_name'. Please install it manually (sudo apt install $package_name) and run the script again."
            exit 1
        fi
        echo "✅ '$package_name' installed successfully."
    fi
}

# --- Tool Check and Installation ---
# ocrmypdf and Tesseract are for OCR
install_package ocrmypdf
install_package tesseract-ocr-eng 
# imagemagick is now needed to clean up potentially corrupted JPEG files
install_package imagemagick

# --- Get User Input ---
echo "--- Image to Searchable PDF Converter ---"

# Ask for Source Directory
read -r -p "Enter the **source directory** (folder containing images): " SOURCE_DIR
SOURCE_DIR=$(realpath -s "$SOURCE_DIR") # Resolve to absolute path

# Validate Source Directory
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Source directory '$SOURCE_DIR' does not exist or is not a directory."
    exit 1
fi

# Ask for Destination Directory
read -r -p "Enter the **destination directory** (where PDFs will be saved): " DEST_DIR
DEST_DIR=$(realpath -s "$DEST_DIR") # Resolve to absolute path

# Create Destination Directory if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
    echo "Creating destination directory: '$DEST_DIR'"
    mkdir -p "$DEST_DIR"
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create destination directory: '$DEST_DIR'"
        exit 1
    fi
fi

# Define a temporary file location
TEMP_TIFF="/tmp/ocrmypdf_temp_image.tiff"

echo "--- Starting Conversion ---"

# --- Main Processing Loop ---
find "$SOURCE_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.tif" -o -iname "*.tiff" \) -print0 | 
while IFS= read -r -d $'\0' IMAGE_PATH; do
    
    FILENAME=$(basename -- "$IMAGE_PATH")
    BASE_NAME=$(echo "$FILENAME" | rev | cut -f 2- -d '.' | rev)
    OUTPUT_PDF="$DEST_DIR/$BASE_NAME.pdf"

    echo "▶️ Processing: '$FILENAME'"
    echo "   Saving to: '$BASE_NAME.pdf'"
    
    # Step 1: Use ImageMagick's convert to create a clean TIFF file
    echo "   (1/3) Cleaning image using 'convert'..."
    convert "$IMAGE_PATH" "$TEMP_TIFF"

    if [ $? -ne 0 ]; then
        echo "❌ Failed to clean image using 'convert'. Skipping file."
        continue # Skip to the next file
    fi
    
    # Step 2: Run ocrmypdf on the clean TIFF file
    echo "   (2/3) Running OCR on clean TIFF..."
    # --skip-text and --image-dpi 300 are retained for robust OCR
    # --optimize 0 is no longer needed as 'convert' fixed the underlying issue
    ocrmypdf -l eng --skip-text --output-type pdf --image-dpi 300 "$TEMP_TIFF" "$OUTPUT_PDF"
    
    if [ $? -eq 0 ]; then
        echo "✅ (3/3) Successfully converted and OCR'd: '$FILENAME'"
    else
        echo "❌ Failed to process: '$FILENAME' using ocrmypdf."
    fi

    # Step 3: Clean up the temporary file
    rm -f "$TEMP_TIFF"
    
    echo "----------------------------------------------------"
done

echo "--- Conversion Complete ---"
echo "All processable images in '$SOURCE_DIR' have been converted to searchable PDFs in '$DEST_DIR'."

exit 0
