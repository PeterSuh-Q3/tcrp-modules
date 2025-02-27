#!/bin/bash

# SHA256 체크섬 계산
installsha=$(sha256sum ./src/install.sh | awk '{print $1}')
sbintgzsha=$(sha256sum ./releases/sbin.tgz | awk '{print $1}')

# 파일 다운로드 및 체크섬 업데이트 함수
update_checksum() {
    local platform=$1
    local kver=$2
    local jsonfile=$3

    # 체크섬 파일 다운로드
    if [ ! -f files-chksum ]; then
        cd ./releases/
        URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/files-chksum"
        curl -kLO $URL
        cd ..
    fi

    # firmware 체크섬
    firmware=$(grep firmware.tgz files-chksum | grep firmware.sha256|awk '{print $1}')

    # 모듈 체크섬
    value=$(grep ${platform}-${kver}.tgz files-chksum | grep modpack.sha256|awk '{print $1}')

    # JSON 파일 업데이트
    org=$(jq -r '.files[0].sha256' "$jsonfile")
    sed -i "s/$org/$value/" "$jsonfile"

    orgfirmware=$(jq -r '.files[1].sha256' "$jsonfile")
    sed -i "s/$orgfirmware/$firmware/" "$jsonfile"

    orginstall=$(jq -r '.files[2].sha256' "$jsonfile")
    sed -i "s/$orginstall/$installsha/" "$jsonfile"

    orgsbintgz=$(jq -r '.files[3].sha256' "$jsonfile")
    sed -i "s/$orgsbintgz/$sbintgzsha/" "$jsonfile"

    # 파일 다운로드
    URL="https://github.com/PeterSuh-Q3/arpl-modules/releases/latest/download/${platform}-${kver}.tgz"
    echo "$URL"
    curl -kLO $URL
}

# bromolow 및 epyc7002 처리
for platform in bromolow epyc7002; do
    echo "modify $platform.json"

    if [ "$platform" = "bromolow" ]; then
        kver="3.10.108"
        update_checksum "$platform" "$kver" "$platform.json"
    elif [ "$platform" = "epyc7002" ]; then
        kver="5.10.55"
        update_checksum "$platform" "7.1-$kver" "$platform.json"
        update_checksum "$platform" "7.2-$kver" "${platform}72.json"
    fi
done

# 다른 플랫폼 처리
for platform in apollolake broadwell broadwellnk denverton geminilake v1000 r1000 broadwellnkv2 broadwellntbap purley; do
    echo "modify $platform.json"
    kver="4.4.180"
    update_checksum "$platform" "$kver" "$platform.json"

    kver="4.4.302"
    update_checksum "$platform" "$kver" "$platform.json"
    update_checksum "$platform" "$kver" "${platform}72.json"
done
