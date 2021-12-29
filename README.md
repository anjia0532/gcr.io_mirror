Google Container Registry Mirror(Google Container Registry镜像加速)
-------

Syntax/语法
-------

```bash
# origin / 原镜像名称
gcr.io/namespace/image_name:image_tag
 
# eq / 等同于
anjia0532/namespace.image_name:image_tag

# special / 特别的
k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> anjia0532/google-containers.image_name:image_tag 
```

Uses/如何拉取新镜像
-------
[创建issues](https://github.com/anjia0532/gcr.io_mirror/issues/new?assignees=&labels=porter&template=gcr-io_porter.md&title=%5BPORTER%5D) ,将自动触发 github actions 进行拉取转推到docker hub

**注意：**

issues标题必须为 `[PORTER]镜像名:tag` 的格式，例如`[PORTER]k8s.gcr.io/federation-controller-manager-arm64:v1.3.1-beta.1`,`[PORTER]gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1`

issues的内容无所谓，可以为空

可以参考 [已搬运镜像集锦](https://github.com/anjia0532/gcr.io_mirror/issues?q=is%3Aissue+label%3Aporter+)

**注意:**

本项目目前仅支持 gcr.io和k8s.gcr.io 镜像

ReTag anjia0532 images to gcr.io/ 将加速下载的镜像重命名为gcr.io
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