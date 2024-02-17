#!/bin/bash

installsha=$(sha256sum ./src/install.sh | awk '{print $1}')
echo "$installsha"

sbintgzsha=$(sha256sum ./releases/sbin.tgz | awk '{print $1}')
echo "$sbintgzsha"

cd ./releases/

URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/files-chksum"
echo "$URL"
curl -kLO $URL

firmware=`grep firmware.tgz files-chksum | grep firmware.sha256|awk '{print $1}'`
echo "firmware sha256=$firmware"

URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/firmware.tgz"
echo "$URL"
curl -kLO $URL

for platform in bromolow epyc7002; do
    echo "modify $platform.json"
    
    if [ "$platform" = "bromolow" ]||[ "$platform" = "braswell" ]; then
        kver="3.10.108"

        value=`grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
        echo "$value"    
    
        org=$(jq -r '.files[0].sha256' "${platform}.json")
        sed -i "s/$org/$value/" "${platform}.json"
    
        orgfirmware=$(jq -r '.files[1].sha256' "${platform}.json")
        sed -i "s/$orgfirmware/$firmware/" "${platform}.json"
    
        orginstall=$(jq -r '.files[2].sha256' "${platform}.json")
        sed -i "s/$orginstall/$installsha/" "${platform}.json"
    
        orgsbintgz=$(jq -r '.files[3].sha256' "${platform}.json")
        sed -i "s/$orgsbintgz/$sbintgzsha/" "${platform}.json"

        URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
        echo "$URL"
        curl -kLO $URL
        
    elif [ "$platform" = "epyc7002" ]; then
        kver="5.10.55"

        # 7.1
        value=`grep ${platform}-7.1-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
        echo "$value"    
    
        org=$(jq -r '.files[0].sha256' "${platform}.json")
        sed -i "s/$org/$value/" "${platform}.json"
    
        orgfirmware=$(jq -r '.files[1].sha256' "${platform}.json")
        sed -i "s/$orgfirmware/$firmware/" "${platform}.json"
    
        orginstall=$(jq -r '.files[2].sha256' "${platform}.json")
        sed -i "s/$orginstall/$installsha/" "${platform}.json"
    
        orgsbintgz=$(jq -r '.files[3].sha256' "${platform}.json")
        sed -i "s/$orgsbintgz/$sbintgzsha/" "${platform}.json"

        URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-7.1-${kver}.tgz"
        echo "$URL"
        curl -kLO $URL

        # 7.2
        value=`grep ${platform}-7.2-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
        echo "$value"    
    
        org=$(jq -r '.files[0].sha256' "${platform}72.json")
        sed -i "s/$org/$value/" "${platform}72.json"
    
        orgfirmware=$(jq -r '.files[1].sha256' "${platform}72.json")
        sed -i "s/$orgfirmware/$firmware/" "${platform}72.json"
    
        orginstall=$(jq -r '.files[2].sha256' "${platform}72.json")
        sed -i "s/$orginstall/$installsha/" "${platform}72.json"
    
        orgsbintgz=$(jq -r '.files[3].sha256' "${platform}72.json")
        sed -i "s/$orgsbintgz/$sbintgzsha/" "${platform}72.json"

        URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-7.2-${kver}.tgz"
        echo "$URL"
        curl -kLO $URL
        
    fi
    
done


for platform in apollolake broadwell broadwellnk denverton geminilake v1000 r1000; do
    echo "modify $platform.json"
    
    kver="4.4.180"
    
    value=`grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
    echo "$value"    

    org=$(jq -r '.files[0].sha256' "${platform}.json")
    sed -i "s/$org/$value/" "${platform}.json"

    value=`grep ${platform}-4.4.302.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
    echo "$value"
    
    org=$(jq -r '.files[1].sha256' "${platform}.json")
    sed -i "s/$org/$value/" "${platform}.json"

    orgfirmware=$(jq -r '.files[2].sha256' "${platform}.json")
    sed -i "s/$orgfirmware/$firmware/" "${platform}.json"

    orginstall=$(jq -r '.files[3].sha256' "${platform}.json")
    sed -i "s/$orginstall/$installsha/" "${platform}.json"

    orgsbintgz=$(jq -r '.files[4].sha256' "${platform}.json")
    sed -i "s/$orgsbintgz/$sbintgzsha/" "${platform}.json"

    URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
    echo "$URL"
    curl -kLO $URL
    
done

for platform in apollolake broadwell broadwellnk denverton geminilake v1000 r1000; do
    echo "modify ${platform}72.json"

    kver="4.4.302"
    
    value=`grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}'`
    echo "$value"
    
    org=$(jq -r '.files[0].sha256' "${platform}72.json")
    sed -i "s/$org/$value/" "${platform}72.json"

    orgfirmware=$(jq -r '.files[1].sha256' "${platform}72.json")
    sed -i "s/$orgfirmware/$firmware/" "${platform}72.json"

    orginstall=$(jq -r '.files[2].sha256' "${platform}72.json")
    sed -i "s/$orginstall/$installsha/" "${platform}72.json"

    orgsbintgz=$(jq -r '.files[3].sha256' "${platform}72.json")
    sed -i "s/$orgsbintgz/$sbintgzsha/" "${platform}72.json"

    URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
    echo "$URL"
    curl -kLO $URL
    
done

#git add .; git commit -am "lastest releases"; git push;
