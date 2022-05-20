#!/bin/sh

k8s_img=$1
mirror_img=$(echo ${k8s_img}|
        sed 's/k8s\.gcr\.io/anjia0532\/google-containers/g;s/gcr\.io/anjia0532/g;s/\//\./g;s/ /\n/g;s/anjia0532\./anjia0532\//g' |
        uniq)

sudo docker pull ${mirror_img}
sudo docker tag ${mirror_img} ${k8s_img}
