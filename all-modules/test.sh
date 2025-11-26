#!/bin/bash

installsha=$(sha256sum ./src/install.sh | awk '{print $1}')

cd ./releases/

echo "Verifying install.sh sha256 in all JSON files:"
echo "Expected sha256: $installsha"
echo ""

for json_file in *.json; do
    actual_sha=$(jq -r '.files[2].sha256' "$json_file" 2>/dev/null)
    filename=$(jq -r '.files[2].name' "$json_file" 2>/dev/null)
    
    if [ "$filename" = "install.sh" ]; then
        if [ "$actual_sha" = "$installsha" ]; then
            echo "✓ $json_file - OK"
        else
            echo "✗ $json_file - MISMATCH (found: $actual_sha)"
        fi
    else
        echo "⚠ $json_file - Warning: .files[2] is '$filename', not 'install.sh'"
    fi
done

