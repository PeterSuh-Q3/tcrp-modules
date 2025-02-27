#!/bin/bash

# SHA256 체크섬 계산
installsha=$(sha256sum ./src/install.sh | awk '{print $1}')
sbintgzsha=$(sha256sum ./releases/sbin.tgz | awk '{print $1}')
firmwaresha=$(curl -kLO https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/files-chksum && grep firmware.tgz files-chksum | grep firmware.sha256|awk '{print $1}')

# firmware 다운로드
curl -kLO https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/firmware.tgz

# 플랫폼별 처리
for platform in bromolow epyc7002; do
    if [ "$platform" = "bromolow" ]; then
        kver="3.10.108"
        value=$(grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}')
        jsonfile="${platform}.json"
    elif [ "$platform" = "epyc7002" ]; then
        kver="5.10.55"
        value=$(grep ${platform}-7.1-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}')
        jsonfile="${platform}.json"
        
        # epyc7002의 7.2 버전 처리
        value72=$(grep ${platform}-7.2-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}')
        jsonfile72="${platform}72.json"
    fi
    
    # bromolow 및 epyc7002 처리
    if [ "$platform" = "bromolow" ]; then
        sed -i "s/$(jq -r '.files[0].sha256' "${jsonfile}")/$value/; s/$(jq -r '.files[1].sha256' "${jsonfile}")/$firmwaresha/; s/$(jq -r '.files[2].sha256' "${jsonfile}")/$installsha/; s/$(jq -r '.files[3].sha256' "${jsonfile}")/$sbintgzsha/" "${jsonfile}"
        curl -kLO https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz
    elif [ "$platform" = "epyc7002" ]; then
        sed -i "s/$(jq -r '.files[0].sha256' "${jsonfile}")/$value/; s/$(jq -r '.files[1].sha256' "${jsonfile}")/$firmwaresha/; s/$(jq -r '.files[2].sha256' "${jsonfile}")/$installsha/; s/$(jq -r '.files[3].sha256' "${jsonfile}")/$sbintgzsha/" "${jsonfile}"
        curl -kLO https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-7.1-${kver}.tgz
        
        # epyc7002의 7.2 버전 처리
        sed -i "s/$(jq -r '.files[0].sha256' "${jsonfile72}")/$value72/; s/$(jq -r '.files[1].sha256' "${jsonfile72}")/$firmwaresha/; s/$(jq -r '.files[2].sha256' "${jsonfile72}")/$installsha/; s/$(jq -r '.files[3].sha256' "${jsonfile72}")/$sbintgzsha/" "${jsonfile72}"
        curl -kLO https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-7.2-${kver}.tgz
    fi
done

# 다른 플랫폼 처리
for platform in apollolake broadwell broadwellnk denverton geminilake v1000 r1000 broadwellnkv2 broadwellntbap purley; do
    kver="4.4.180"
    value=$(grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}')
    jsonfile="${platform}.json"
    
    # 4.4.302 버전 처리
    value302=$(grep ${platform}-4.4.302.tgz files-chksum | grep modpack.sha256|awk '{print $1}')
    jsonfile302="${platform}.json"
    
    # 72 버전 처리
    value72=$(grep ${platform}-4.4.302.tgz files-chksum | grep modpack.sha256|awk '{print $1}')
    jsonfile72="${platform}72.json"
    
    # 처리
    sed -i "s/$(jq -r '.files[0].sha256' "${jsonfile}")/$value/; s/$(jq -r '.files[1].sha256' "${jsonfile}")/$value302/; s/$(jq -r '.files[2].sha256' "${jsonfile}")/$firmwaresha/; s/$(jq -r '.files[3].sha256' "${jsonfile}")/$installsha/; s/$(jq -r '.files[4].sha256' "${jsonfile}")/$sbintgzsha/" "${jsonfile}"
    curl -kLO https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz
    
    # 72 버전 처리
    sed -i "s/$(jq -r '.files[0].sha256' "${jsonfile72}")/$value72/; s/$(jq -r '.files[1].sha256' "${jsonfile72}")/$firmwaresha/; s/$(jq -r '.files[2].sha256' "${jsonfile72}")/$installsha/; s/$(jq -r '.files[3].sha256' "${jsonfile72}")/$sbintgzsha/" "${jsonfile72}"
    curl -kLO https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-4.4.302.tgz
done
