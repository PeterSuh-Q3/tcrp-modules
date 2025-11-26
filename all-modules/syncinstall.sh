#!/bin/bash

installsha=$(sha256sum ./src/install.sh | awk '{print $1}')
echo "New install.sh sha256: $installsha"

cd ./releases/

for json_file in *.json; do
    echo "Updating $json_file"
    jq ".files[2].sha256 = \"$installsha\"" "$json_file" | sponge "$json_file"
done

echo "Done!"
