Google Container Registry Mirror [last sync 2018-11-19 16:26 UTC]
-------
[![Sync Status](https://travis-ci.org/anjia0532/gcr.io_mirror.svg?branch=sync)](https://travis-ci.org/anjia0532/gcr.io_mirror)

**Oops**

![](http://ww1.sinaimg.cn/large/afaffa71ly1fxe8g1k4jwj20gt0850t1.jpg)

**Azure Mirrors**

thanks for @zebang li share this news!

![](http://ww1.sinaimg.cn/large/afaffa71ly1g0l50nuqjlj20fo0aa3z5.jpg)

Syntax
-------

```bash
gcr.io/namespace/image_name:image_tag 
#eq
gcr.azk8s.cn/namespace/image_name:image_tag 

# special
k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> gcr.azk8s.cn/namespace/image_name:image_tag 
```

~~Add new namespace~~
-------
[Fork and edit sync branch file gcr_namespaces](https://github.com/anjia0532/gcr.io_mirror/edit/sync/gcr_namespaces)

append new line about namespace(e.g. `gcr.io/google-containers`  u should append `google-containers`,`k8s.gcr.io` eq `gcr.io/google-containers`)

save and commit a PR for this repo.

Example
-------

```bash

docker pull gcr.azk8s.cn/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 
# eq
docker pull gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 

# special
# eq 
docker pull k8s.gcr.io/federation-controller-manager-arm64:v1.3.1-beta.1
```

~~ReTag anjia0532 images to gcr.io~~
-------

```bash
# replace gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 to real image
# this will convert gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 
# to anjia0532/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 and pull it
# k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> anjia0532/google-containers.{image}/{tag}

images=$(cat img.txt)
#or 
#images=$(cat <<EOF
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
#EOF
#)

eval $(echo ${images}|
        sed 's/k8s\.gcr\.io/anjia0532\/google-containers/g;s/gcr\.io/anjia0532/g;s/\//\./g;s/ /\n/g;s/anjia0532\./anjia0532\//g' |
        uniq |
        awk '{print "docker pull "$1";"}'
       )

# this code will retag all of anjia0532's image from local  e.g. anjia0532/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 
# to gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> anjia0532/google-containers.{image}/{tag}

for img in $(docker images --format "{{.Repository}}:{{.Tag}}"| grep "anjia0532"); do
  n=$(echo ${img}| awk -F'[/.:]' '{printf "gcr.io/%s",$2}')
  image=$(echo ${img}| awk -F'[/.:]' '{printf "/%s",$3}')
  tag=$(echo ${img}| awk -F'[:]' '{printf ":%s",$2}')
  docker tag $img "${n}${image}${tag}"
  [[ ${n} == "gcr.io/google-containers" ]] && docker tag $img "k8s.gcr.io${image}${tag}"
done
```

[Changelog](./CHANGES.md)
-------

~~Mirror 14 namespaces image from gcr.io~~
-----


[gcr.io/runconduit/*](./runconduit/README.md)


[gcr.io/google-samples/*](./google-samples/README.md)


[gcr.io/kubernetes-helm/*](./kubernetes-helm/README.md)


[gcr.io/k8s-minikube/*](./k8s-minikube/README.md)


[gcr.io/tf-on-k8s-dogfood/*](./tf-on-k8s-dogfood/README.md)


[gcr.io/spinnaker-marketplace/*](./spinnaker-marketplace/README.md)


[gcr.io/google-containers/*](./google-containers/README.md)


[gcr.io/distroless/*](./distroless/README.md)


[gcr.io/istio-release/*](./istio-release/README.md)


[gcr.io/linkerd-io/*](./linkerd-io/README.md)


[gcr.io/cloud-datalab/*](./cloud-datalab/README.md)


[gcr.io/kubeflow-images-public/*](./kubeflow-images-public/README.md)


[gcr.io/cloudsql-docker/*](./cloudsql-docker/README.md)


[gcr.io/google-appengine/*](./google-appengine/README.md)


