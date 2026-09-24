#!/bin/bash

sed_i () {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$1" "$2"
  else
    sed -i "$1" "$2"
  fi
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
installsha=$(sha256sum "$script_dir/src/install.sh" | awk '{print $1}')
firmware=$(sha256sum "$script_dir/../firmware/common/firmware.tgz" | awk '{print $1}')
firmwarei915=$(sha256sum "$script_dir/../firmware/common/firmwarei915.tgz" | awk '{print $1}')
echo "$installsha"

echo "firmware sha256=$firmware"
echo "firmwarei915 sha256=$firmwarei915"

cd "$script_dir/releases/"

URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/files-chksum"
echo "$URL"
curl -kLO $URL

for platform in avoton cedarview bromolow braswell grantley; do
    echo "modify $platform.json"

    if [ "$platform" = "bromolow" ]||[ "$platform" = "braswell" ]||[ "$platform" = "grantley" ]; then
        kver="3.10.105"
    
        value=`grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
        echo "$value"    
    
        org=$(jq -r '.files[0].sha256' "${platform}62.json")
        sed_i "s/$org/$value/" "${platform}62.json"
    
        orgfirmware=$(jq -r '.files[1].sha256' "${platform}62.json")
        sed_i "s/$orgfirmware/$firmware/" "${platform}62.json"
    
        orginstall=$(jq -r '.files[2].sha256' "${platform}62.json")
        sed_i "s/$orginstall/$installsha/" "${platform}62.json"
    
        URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
        echo "$URL"
        curl -kLO $URL
    fi

    kver="3.10.108"

    value=`grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
    echo "$value"    

    org=$(jq -r '.files[0].sha256' "${platform}71.json")
    sed_i "s/$org/$value/" "${platform}71.json"

    orgfirmware=$(jq -r '.files[1].sha256' "${platform}71.json")
    sed_i "s/$orgfirmware/$firmware/" "${platform}71.json"

    orginstall=$(jq -r '.files[2].sha256' "${platform}71.json")
    sed_i "s/$orginstall/$installsha/" "${platform}71.json"

    URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
    echo "$URL"
    curl -kLO $URL
 
done

#don't touch bromolow,braswell 2024.12.22
#Add bromolow again 2025.02.17
for platform in epyc7002 v1000nk r1000nk geminilakenk; do
    echo "modify $platform.json"
        
    if [ "$platform" = "epyc7002" ]; then
        kver="5.10.55"

        # 7.1 remark to use rr's module
        value=`grep ${platform}-7.1-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
        echo "$value"    
    
        org=$(jq -r '.files[0].sha256' "${platform}71.json")
        sed_i "s/$org/$value/" "${platform}71.json"
    
        orgfirmware=$(jq -r '.files[1].sha256' "${platform}71.json")
        sed_i "s/$orgfirmware/$firmware/" "${platform}71.json"
    
        orginstall=$(jq -r '.files[2].sha256' "${platform}71.json")
        sed_i "s/$orginstall/$installsha/" "${platform}71.json"

        orgfirmwarei915=$(jq -r '.files[3].sha256' "${platform}71.json")
        sed_i "s/$orgfirmwarei915/$firmwarei915/" "${platform}71.json"

        URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-7.1-${kver}.tgz"
        echo "$URL"
        curl -kLO $URL

        # 7.2 remark to use rr's module
        value=`grep ${platform}-7.2-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
        echo "$value"    
    
        org=$(jq -r '.files[0].sha256' "${platform}72.json")
        sed_i "s/$org/$value/" "${platform}72.json"
    
        orgfirmware=$(jq -r '.files[1].sha256' "${platform}72.json")
        sed_i "s/$orgfirmware/$firmware/" "${platform}72.json"
    
        orginstall=$(jq -r '.files[2].sha256' "${platform}72.json")
        sed_i "s/$orginstall/$installsha/" "${platform}72.json"

        orgfirmwarei915=$(jq -r '.files[3].sha256' "${platform}72.json")
        sed_i "s/$orgfirmwarei915/$firmwarei915/" "${platform}72.json"

        URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-7.2-${kver}.tgz"
        echo "$URL"
        curl -kLO $URL

        cp -vf "${platform}-7.2-${kver}.tgz" "${platform}-7.3-${kver}.tgz"
        cp -vf "${platform}72.json" "${platform}73.json"

    elif [ "$platform" = "v1000nk" ]||[ "$platform" = "r1000nk" ]||[ "$platform" = "geminilakenk" ]; then
        kver="5.10.55"

        # 7.2 remark to use rr's module
        value=`grep ${platform}-7.2-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
        echo "$value"    
    
        org=$(jq -r '.files[0].sha256' "${platform}72.json")
        sed_i "s/$org/$value/" "${platform}72.json"
    
        orgfirmware=$(jq -r '.files[1].sha256' "${platform}72.json")
        sed_i "s/$orgfirmware/$firmware/" "${platform}72.json"
    
        orginstall=$(jq -r '.files[2].sha256' "${platform}72.json")
        sed_i "s/$orginstall/$installsha/" "${platform}72.json"

        orgfirmwarei915=$(jq -r '.files[3].sha256' "${platform}72.json")
        sed_i "s/$orgfirmwarei915/$firmwarei915/" "${platform}72.json"

        URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-7.2-${kver}.tgz"
        echo "$URL"
        curl -kLO $URL

        cp -vf "${platform}-7.2-${kver}.tgz" "${platform}-7.3-${kver}.tgz"
        cp -vf "${platform}72.json" "${platform}73.json"
    fi
done

for platform in apollolake broadwellnk denverton geminilake v1000 purley broadwellntbap; do
    echo "modify $platform.json"
    
    kver="4.4.59"
    
    value=`grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
    echo "$value"    

    org=$(jq -r '.files[0].sha256' "${platform}62.json")
    sed_i "s/$org/$value/" "${platform}62.json"

    orgfirmware=$(jq -r '.files[1].sha256' "${platform}62.json")
    sed_i "s/$orgfirmware/$firmware/" "${platform}62.json"

    orginstall=$(jq -r '.files[2].sha256' "${platform}62.json")
    sed_i "s/$orginstall/$installsha/" "${platform}62.json"

    URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
    echo "$URL"
    curl -kLO $URL
done

for platform in apollolake broadwell broadwellnk denverton geminilake v1000 r1000 broadwellnkv2 broadwellntbap purley; do
    echo "modify $platform.json"

    if [ "$platform" = "broadwell" ]; then
        kver="3.10.105"
    
        value=`grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
        echo "$value"    
    
        org=$(jq -r '.files[0].sha256' "${platform}62.json")
        sed_i "s/$org/$value/" "${platform}62.json"
    
        orgfirmware=$(jq -r '.files[1].sha256' "${platform}62.json")
        sed_i "s/$orgfirmware/$firmware/" "${platform}62.json"
    
        orginstall=$(jq -r '.files[2].sha256' "${platform}62.json")
        sed_i "s/$orginstall/$installsha/" "${platform}62.json"
    
        URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
        echo "$URL"
        curl -kLO $URL
    fi
    
    kver="4.4.180"
    
    value=`grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
    echo "$value"    

    org=$(jq -r '.files[0].sha256' "${platform}71.json")
    sed_i "s/$org/$value/" "${platform}71.json"

    orgfirmware=$(jq -r '.files[1].sha256' "${platform}71.json")
    sed_i "s/$orgfirmware/$firmware/" "${platform}71.json"

    orginstall=$(jq -r '.files[2].sha256' "${platform}71.json")
    sed_i "s/$orginstall/$installsha/" "${platform}71.json"

    URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
    echo "$URL"
    curl -kLO $URL
done

for platform in apollolake broadwell broadwellnk denverton geminilake v1000 r1000 broadwellnkv2 broadwellntbap purley; do
    echo "modify ${platform}72.json"

    kver="4.4.302"
    
    value=`grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
    echo "$value"
    
    org=$(jq -r '.files[0].sha256' "${platform}72.json")
    sed_i "s/$org/$value/" "${platform}72.json"

    orgfirmware=$(jq -r '.files[1].sha256' "${platform}72.json")
    sed_i "s/$orgfirmware/$firmware/" "${platform}72.json"

    orginstall=$(jq -r '.files[2].sha256' "${platform}72.json")
    sed_i "s/$orginstall/$installsha/" "${platform}72.json"

    URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
    echo "$URL"
    curl -kLO $URL
done

#git add .; git commit -am "lastest releases"; git push;
