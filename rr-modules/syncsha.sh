#!/bin/bash

installsha=$(sha256sum ./src/install.sh | awk '{print $1}')
echo "$installsha"

sbintgzsha=$(sha256sum ./releases/sbin.tgz | awk '{print $1}')
echo "$sbintgzsha"

cd ./releases/

firmware=$(sha256sum ./releases/firmware.tgz | awk '{print $1}')
echo "firmware sha256=$firmware"

for platform in apollolake broadwell broadwellnk denverton geminilake v1000 r1000; do
    echo "modify $platform.json"
    
    kver="4.4.180"
    
    value=$(sha256sum ./releases/${platform}-${kver}.tgz | awk '{print $1}')
    echo "$value"    

    org=$(jq -r '.files[0].sha256' "${platform}.json")
    sed -i "s/$org/$value/" "${platform}.json"

    value=$(sha256sum ./releases/${platform}-4.4.302.tgz | awk '{print $1}')
    echo "$value"
    
    org=$(jq -r '.files[1].sha256' "${platform}.json")
    sed -i "s/$org/$value/" "${platform}.json"

    orgfirmware=$(jq -r '.files[2].sha256' "${platform}.json")
    sed -i "s/$orgfirmware/$firmware/" "${platform}.json"

    orginstall=$(jq -r '.files[3].sha256' "${platform}.json")
    sed -i "s/$orginstall/$installsha/" "${platform}.json"

    orgsbintgz=$(jq -r '.files[4].sha256' "${platform}.json")
    sed -i "s/$orgsbintgz/$sbintgzsha/" "${platform}.json"
    
done

for platform in apollolake broadwell broadwellnk denverton geminilake v1000 r1000; do
    echo "modify ${platform}72.json"

    kver="4.4.302"

    value=$(sha256sum ./releases/${platform}-${kver}.tgz | awk '{print $1}')    
    echo "$value"
    
    org=$(jq -r '.files[0].sha256' "${platform}72.json")
    sed -i "s/$org/$value/" "${platform}72.json"

    orgfirmware=$(jq -r '.files[1].sha256' "${platform}72.json")
    sed -i "s/$orgfirmware/$firmware/" "${platform}72.json"

    orginstall=$(jq -r '.files[2].sha256' "${platform}72.json")
    sed -i "s/$orginstall/$installsha/" "${platform}72.json"

    orgsbintgz=$(jq -r '.files[3].sha256' "${platform}72.json")
    sed -i "s/$orgsbintgz/$sbintgzsha/" "${platform}72.json"
    
done

#git add .; git commit -am "lastest releases"; git push;
