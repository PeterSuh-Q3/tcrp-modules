#!/bin/bash

baseurl="https://raw.githubusercontent.com/PeterSuh-Q3/tcrp-modules/main"  # Base URL

ls -d */ | grep -e ddsml -e eudev | while IFS= read -r dir; do
  for baseplatform in `cat addplatforms`
  do 
    
    echo "Adding ${baseplatform} to ${dir}rpext-index.json"

    jsonfile="./${dir}rpext-index.json"
    model_url="${baseurl}/${dir}recipes/universal.json"
    jq --arg model "${baseplatform}" --arg url "$model_url" '.releases += { ($model): $url }' "$jsonfile" > temp.json && mv temp.json "$jsonfile"    

  done
done
