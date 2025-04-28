#!/bin/bash

installsha=$(sha256sum ./src/install.sh | awk '{print $1}')
echo "$installsha"

cd ./releases/

#don't touch bromolow,braswell 2024.12.22
#Add bromolow again 2025.02.17
for platform in bromolow avoton braswell cedarview grantley epyc7002 v1000nk; do
    echo "modify $platform.json"
    
    if [ "$platform" = "epyc7002" ]; then
        kver="5.10.55"

        # 7.1 remark to use rr's module
        orginstall=$(jq -r '.files[2].sha256' "${platform}.json")
        sed -i "s/$orginstall/$installsha/" "${platform}.json"

        jq '.files |= map(select(.name != "sbin.tgz"))' "${platform}.json" | sponge "${platform}.json"

        # 7.2 remark to use rr's module
        orginstall=$(jq -r '.files[2].sha256' "${platform}72.json")
        sed -i "s/$orginstall/$installsha/" "${platform}72.json"

        jq '.files |= map(select(.name != "sbin.tgz"))' "${platform}72.json" | sponge "${platform}72.json"
    elif [ "$platform" = "v1000nk" ]; then
        kver="5.10.55"

        # 7.2 remark to use rr's module
        orginstall=$(jq -r '.files[2].sha256' "${platform}72.json")
        sed -i "s/$orginstall/$installsha/" "${platform}72.json"
        jq '.files |= map(select(.name != "sbin.tgz"))' "${platform}72.json" | sponge "${platform}72.json"        
    else
        kver="3.10.108"
   
        orginstall=$(jq -r '.files[2].sha256' "${platform}.json")
        sed -i "s/$orginstall/$installsha/" "${platform}.json"

        jq '.files |= map(select(.name != "sbin.tgz"))' "${platform}.json" | sponge "${platform}.json"        
    fi
    
done

for platform in apollolake broadwell broadwellnk denverton geminilake v1000 r1000 broadwellnkv2 broadwellntbap purley; do
    echo "modify $platform.json"
    
    kver="4.4.180"

    orginstall=$(jq -r '.files[3].sha256' "${platform}.json")
    sed -i "s/$orginstall/$installsha/" "${platform}.json"

    jq '.files |= map(select(.name != "sbin.tgz"))' "${platform}.json" | sponge "${platform}.json"    

    orginstall=$(jq -r '.files[2].sha256' "${platform}72.json")
    sed -i "s/$orginstall/$installsha/" "${platform}72.json"

    jq '.files |= map(select(.name != "sbin.tgz"))' "${platform}72.json" | sponge "${platform}72.json"    
    
done

#git add .; git commit -am "lastest releases"; git push;
