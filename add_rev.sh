#!/bin/bash

if [ -z "$1" ]; then
  echo "Please provide a revision as an argument."
  exit 1
fi

curl -kLO https://raw.githubusercontent.com/PeterSuh-Q3/tinycore-redpill/main/myfunc.h

##### INCLUDES #########################################################################################################
source myfunc.h # my.sh / myv.sh common use 

rev="$1"
baseurl="https://raw.githubusercontent.com/PeterSuh-Q3/tcrp-modules/master"  # Base URL

ls -d */ | grep -v -e "all-modules" | while IFS= read -r dir; do
  for basemodel in `cat models.72`
  do 
    model=$(echo "${basemodel}" | sed 's/DS/ds/' | sed 's/RS/rs/' | sed 's/+/p/' | sed 's/DVA/dva/' | sed 's/FS/fs/' | sed 's/SA/sa/' )
    echo "Adding ${model}_${rev} to ${dir}rpext-index.json"

    jsonfile="./${dir}rpext-index.json"
    model_url="${baseurl}/${dir}recipes/universal.json"
    jq --arg model "${model}_${rev}" --arg url "$model_url" '.releases += { ($model): $url }' "$jsonfile" > temp.json && mv temp.json "$jsonfile"    

  done
done

ls -d */ | grep "all-modules" | while IFS= read -r dir; do
  for basemodel in `cat models.72`
  do 
    getvarsmshell "$basemodel"
    echo "ORIGIN_PLATFORM=$ORIGIN_PLATFORM"                                                          
  
    model=$(echo "${basemodel}" | sed 's/DS/ds/' | sed 's/RS/rs/' | sed 's/+/p/' | sed 's/DVA/dva/' | sed 's/FS/fs/' | sed 's/SA/sa/' )
    echo "Adding ${model}_${rev} to ${dir}rpext-index.json"

    jsonfile="./${dir}rpext-index.json"
    model_url="${baseurl}/${dir}releases/${ORIGIN_PLATFORM}72.json"
    jq --arg model "${model}_${rev}" --arg url "$model_url" '.releases += { ($model): $url }' "$jsonfile" > temp.json && mv temp.json "$jsonfile"    

  done
done
