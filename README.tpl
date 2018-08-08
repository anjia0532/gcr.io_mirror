Google Container Registry Mirror [last sync ${current_date} UTC]
-------

[![Sync Status](https://travis-ci.org/${user_name}/gcr.io_mirror.svg?branch=sync)](https://travis-ci.org/${user_name}/gcr.io_mirror)

Syntax
-------

```bash
gcr.io/namespace/image_name:image_tag 
#eq
${user_name}/namespace.image_name:image_tag

# special
k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> ${user_name}/google-containers.{image}/{tag}
```

Add new namespace
-------
[Fork and edit sync branch file gcr_namespaces](https://github.com/anjia0532/gcr.io_mirror/edit/sync/gcr_namespaces)

append new line about namespace(e.g. `gcr.io/google-containers`  u should append `google-containers`,`k8s.gcr.io` eq `gcr.io/google-containers`)

save and commit a PR for this repo.

Example
-------

```bash

docker pull ${user_name}/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1
# eq
docker pull gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 

# special
# eq 
docker pull k8s.gcr.io/federation-controller-manager-arm64:v1.3.1-beta.1
```

ReTag ${user_name} images to gcr.io 
-------

```bash
# replace gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 to real image
# this will convert gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 
# to ${user_name}/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 and pull it
# k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> ${user_name}/google-containers.{image}/{tag}

images=$(cat img.txt)
#or 
#images=$(cat <<EOF
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
#EOF
#)

eval $(echo ${images}|
        sed 's/k8s\.gcr\.io/${user_name}\/google-containers/g;s/gcr\.io/${user_name}/g;s/\//\./g;s/ /\n/g;s/${user_name}\./${user_name}\//g' |
        uniq |
        awk '{print "docker pull "$1";"}'
       )

# this code will retag all of ${user_name}'s image from local  e.g. ${user_name}/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 
# to gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> ${user_name}/google-containers.{image}/{tag}

for img in $(docker images --format "{{.Repository}}:{{.Tag}}"| grep "${user_name}"); do
  n=$(echo ${img}| awk -F'[/.:]' '{printf "gcr.io/%s",$2}')
  image=$(echo ${img}| awk -F'[/.:]' '{printf "/%s",$3}')
  tag=$(echo ${img}| awk -F'[:]' '{printf ":%s",$2}')
  docker tag $img "${n}${image}${tag}"
  [[ ${n} == "gcr.io/google-containers" ]] && docker tag $img "k8s.gcr.io${image}${tag}"
done
```

[Changelog](./CHANGES.md)
-------

