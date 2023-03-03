#!/bin/bash

git clone git@github.com:PeterSuh-Q3/tcrp-modules.git

URLS=$(curl -s https://api.github.com/repos/fbelavenuto/arpl-modules/releases/latest | jq -r ".assets[].browser_download_url") 
for file in $URLS; do curl -L --progress-bar "$file" -O; done

mv -f *3.10.108.tgz ~/tcrp-modules/all-modules/releases

mv -f *4.4.180.tgz ~/tcrp-modules/all-modules/releases

rm -f *.tgz

cd ~/tcrp-modules/all-modules/releases

mv bromolow-3.10.108.tgz bromolow-4.4.180.tgz

for platform in $(ls *.json | sed 's/.json//'); do
    value=$(sha256sum "${platform}-4.4.180.tgz" | awk '{print $1}')
    org=$(jq -r '.files[0].sha256' "${platform}.json")
    sed -i "s/$org/$value/g" "${platform}.json"
done

mv bromolow-4.4.180.tgz bromolow-3.10.108.tgz 

git add .; git commit -am "releases v${1}"; git push;
