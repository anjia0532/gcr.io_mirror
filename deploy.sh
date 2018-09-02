#!/usr/bin/env bash

SECONDS=0

source ./process-utils.sh
process_init 30

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ -d "gcr.io_mirror" ]] && rm -rf ./gcr.io_mirror

git clone "https://github.com/${user_name}/gcr.io_mirror.git"

function init_namespace()
{
  n=$1
  echo -e "${yellow}init gcr.io/$n's image...${plain}"
  # get all of the gcr images
  imgs=$(curl -XPOST -ks 'https://console.cloud.google.com/m/gcr/entities/list' \
           -H "Cookie: ${cookie}" \
           -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.7 Safari/537.36' \
           -H 'Content-Type: application/json;charset=UTF-8' \
           -H 'Accept: application/json, text/plain, */*' \
           --data-binary '["'${n}'"]' |
           grep -P '"' |
           sed 's/"gcr.ListEntities"//' |
           cut -d '"' -f2 |
           sort |
           uniq)

  for img in ${imgs[@]}  ; do
   process_run "init_imgs $n $img"
  done
  wait
}

function init_imgs()
{
  n=$1
  img=$2
  echo -e "${yellow}init gcr.io/$n/${img}'s image...${plain}"
  # get all  tags for this image
  gcr_content=$(curl -ks -X GET https://gcr.io/v2/${n}/${img}/tags/list)
  dir=gcr.io_mirror/${n}/${img}/

  # if this image dir not exits
  [[ ! -d ${dir} ]] && mkdir -p ${dir};
  
  # create img tmp file,named by tag's name, set access's time,modify's time by this image manifest's timeUploadedMs
  echo ${gcr_content} | jq -r '.manifest|to_entries[]|select(.value.tag|length>0)|{k: .key,t: .value.tag[0],v: .value.timeUploadedMs} | "tf=${dir}"+.t+".tmp;echo "+.k+">${tf};touch -amd \"$(date \"+%F %T\" -d @" + .v[0:10] +")\" ${tf}"' | while read i; do
    eval $i
  done
  
  # download docker hub tags
  next="https://hub.docker.com/v2/repositories/anjia0532/${n}.${img}/tags/?page_size=100"
  while [ "null" != "${next}" ];do
    hub_content=$(curl -ks -X GET "${next}" )
    next=$(echo $hub_content | jq -r '.next')
    results=$(echo $hub_content | jq -r '.results')
    [[ "null" = "${results}" ]] && break ;
    
    hub_tags=$(echo $results | jq -r '.[]|.name')
    for t in ${hub_tags};do
      touch "${dir}$t.t"
    done
  done
}

function compare()
{
  echo -e "${yellow}compare image diff ...${plain}"
  find ./gcr.io_mirror/ -name "*.tmp" | while read t
  do
    dir=$(dirname $t)
    name=$(basename $t .tmp)
    # rm temp file when docker hub tag is exist
    if [ -e ${dir}/${name}.tag ] && [ -e ${dir}/${name}.t ] && [ $(cat ${dir}/${name}.tag)x = $(cat $t)x ]; then
      rm -rf $t;
    else
      [[ -e ${dir}/${name}.tag ]] && rm -rf ${dir}/${name}.tag
    fi
  done
}

function pull_push_diff()
{
  n=$1
  img=$2
  all_of_imgs=$(find ./gcr.io_mirror -type f -name "*.t*" |wc -l)
  current_ns_imgs=$(find ./gcr.io_mirror/${n}/ -type f -name "*.t*" |wc -l)
  tmps=($(find ./gcr.io_mirror/${n}/${img}/ -type f \( -iname "*.tmp" \) -exec basename {} .tmp \; | uniq))
  
  echo -e "${red}wait for mirror${plain}/${yellow}gcr.io/${n}/* images${plain}/${green}all of images${plain}:${red}${#tmps[@]}${plain}/${yellow}${current_ns_imgs}${plain}/${green}${all_of_imgs}${plain}"
  
  for tag in ${tmps[@]} ; do
    echo -e "${yellow}mirror ${n}/${img}/${tag}...${plain}"
    lock=./gcr.io_mirror/${n}/${img}/${tag}.lck
    [[ -e $lock ]] && continue;
    echo "${tag}">$lock
    
    docker pull gcr.io/${n}/${img}:${tag}
    docker tag gcr.io/${n}/${img}:${tag} ${user_name}/${n}.${img}:${tag}
    docker push ${user_name}/${n}.${img}:${tag}
    
    [[ -e ./commit.lck ]] && echo -e "${red} commit.lck exist "&& break
    
    mv ./gcr.io_mirror/${n}/${img}/${tag}.tmp ./gcr.io_mirror/${n}/${img}/${tag}.tag
    
    echo -e "[gcr.io/${n}/${image}:${tag}](https://hub.docker.com/r/${user_name}/${n}.${image}/tags/)\n\n" >> CHANGES.md
    rm -rf $lock
  done
  echo -e "${red} push ${n}/${img} done"
}

function mirror()
{
  num=$(find ./gcr.io_mirror/ -type f \( -iname "*.tmp" \) |wc -l)
  if [ $num -eq 0 ]; then
    ns=$(cat ./gcr_namespaces 2>/dev/null || echo google-containers)
    for n in ${ns[@]}  ; do
      process_run "init_namespace $n"
    done
    wait
  fi
  
  sleep 30
  compare
  sleep 30
  compare
  find ./gcr.io_mirror/ -type f -name "*.t" -exec rm -rf {} \;
  
  tmp_imgs=$(find ./gcr.io_mirror/ -type f \( -iname "*.tmp" \) -exec dirname {} \; | uniq | cut -d'/' -f3-4)
  
  if [ -n "$tmp_imgs[@]" ]; then
    echo -e "${red} wait for push ${tmp_imgs[@]}"
    for img in ${tmp_imgs[@]} ; do
      echo -e "${red} wait for push ${img}"
      n=$(echo ${img}|cut -d'/' -f1)
      image=$(echo ${img}|cut -d'/' -f2)
      process_run "pull_push_diff $n $image"
    done
    wait
  fi
  
  images=($(find ./gcr.io_mirror/ -type f -name "*.tag" |uniq|sort))
  
  cp ./gcr.io_mirror/CHANGES.md ./CHANGES1.md 2>/dev/null
  
  [[ ! -s ./CHANGES1.md ]] && touch ./CHANGES1.md
  
  find ./gcr.io_mirror/ -type f -name "*.md" -exec rm -rf {} \;
    
  for img in ${images[@]} ; do
    n=$(echo ${img}|cut -d'/' -f3)
    image=$(echo ${img}|cut -d'/' -f4)
    tag=$(basename ${img} .tag)
    mkdir -p ./gcr.io_mirror/${n}/${image}
    if [ ! -e ./gcr.io_mirror/${n}/${image}/README.md ]; then
      echo -e "\n[gcr.io/${n}/${image}](https://hub.docker.com/r/${user_name}/${n}.${image}/tags/)\n-----\n\n" >> ./gcr.io_mirror/${n}/${image}/README.md
      echo -e "\n[gcr.io/${n}/${image}](https://hub.docker.com/r/${user_name}/${n}.${image}/tags/)\n-----\n\n" >> ./gcr.io_mirror/${n}/README.md
    fi
    
    echo -e "[gcr.io/${n}/${image}:${tag}](https://hub.docker.com/r/${user_name}/${n}.${image}/tags/)\n\n" >> ./gcr.io_mirror/${n}/${image}/README.md
  done
  
  if [ -s CHANGES.md ]; then
    (echo -e "## $(date +'%Y-%m-%d %H:%M') \n" && cat CHANGES.md 2>/dev/null&& cat CHANGES1.md 2>/dev/null) >> gcr.io_mirror/CHANGES.md
  fi
  commit
}

function commit()
{
  echo 1 > ./commit.lck
  ns=($(cat ./gcr_namespaces 2>/dev/null || echo google-containers))
  readme=./gcr.io_mirror/README.md
  export current_date=$(date +'%Y-%m-%d %H:%M')
  cat README.tpl | envsubst '$user_name $current_date' > "${readme}"
  
  echo -e "Mirror ${#ns[@]} namespaces image from gcr.io\n-----\n\n" >> "${readme}"
  for n in ${ns[@]} ; do
    echo -e "[gcr.io/${n}/*](./${n}/README.md)\n\n" >> "${readme}"
  done
  
  
  echo -e "${red} commit to github master"
  git -C ./gcr.io_mirror pull
  git -C ./gcr.io_mirror add -A
  git -C ./gcr.io_mirror commit -m "sync gcr.io's images at $(date +'%Y-%m-%d %H:%M')"
  git -C ./gcr.io_mirror push -f "https://${user_name}:${GH_TOKEN}@github.com/${user_name}/gcr.io_mirror.git" master:master
  
  echo -e "${red} commit to github master:done"
  echo 1 > ./commit.done
}

mirror &

while true;
do
  duration=$SECONDS
  if [[ -e ./commit.done ]] || [[ $duration -ge $sec ]]; then
    
    [[ $duration -ge $sec ]] && echo -e "${red} more than $(expr $sec / 60) min,abort this build"
    
    [[ ! -e ./commit.done ]] && commit
    
    IFS=$'\n'; for i in $(jobs); do echo "$i"; done
    kill $(jobs -p)
    IFS=$'\n'; for i in $(jobs); do echo "$i"; done
    break
    
  else
    docker_dir=$(docker info | grep "Docker Root Dir" | cut -d':' -f2)
    used=$(df -h ${docker_dir}|awk '{if(NR>1)print $5}')
    echo -e "${red} duration:${duration}s, docker root dir :${docker_dir}:used:${used}"
    [[ ${used} > '60%' ]] && docker system prune -f -a
    sleep 10
  fi
done

sleep 120
echo "${red} bye bye"
