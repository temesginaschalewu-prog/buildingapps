#!/bin/bash

echo "📥 Downloading Roboto font..."

# Roboto Regular
wget -q -O assets/fonts/Roboto/Roboto-Regular.ttf "https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Mu4mxKKTU1Kg.woff2" || echo "Failed to download Roboto Regular"

# Roboto Bold
wget -q -O assets/fonts/Roboto/Roboto-Bold.ttf "https://fonts.gstatic.com/s/roboto/v30/KFOlCnqEu92Fr1MmWUlfBBc4AMP6lQ.woff2" || echo "Failed to download Roboto Bold"

# Roboto Italic
wget -q -O assets/fonts/Roboto/Roboto-Italic.ttf "https://fonts.gstatic.com/s/roboto/v30/KFOkCnqEu92Fr1Mu51xIIzIXKMny.woff2" || echo "Failed to download Roboto Italic"

# Roboto BoldItalic
wget -q -O assets/fonts/Roboto/Roboto-BoldItalic.ttf "https://fonts.gstatic.com/s/roboto/v30/KFOjCnqEu92Fr1Mu51TzBic6CsTYl4BO.woff2" || echo "Failed to download Roboto BoldItalic"

echo "📥 Downloading Inter font..."
echo "Note: Inter font requires manual download from https://rsms.me/inter/"

echo "✅ Font download script created"
echo "Run: chmod +x scripts/download_fonts.sh && ./scripts/download_fonts.sh"
