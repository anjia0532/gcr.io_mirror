Google Container Registry Mirror(Google Container Registry镜像加速)
-------

Syntax/语法
-------

```bash
# origin / 原镜像名称
gcr.io/namespace/{image}:{tag}
 
# eq / 等同于
anjia0532/namespace.{image}:{tag}

# special / 特别的
k8s.gcr.io/{image}:{tag} <==> gcr.io/google-containers/{image}:{tag} <==> anjia0532/google-containers.{image}:{tag}

wget https://raw.githubusercontent.com/anjia0532/gcr.io_mirror/master/pull-k8s-image.sh
chmod +x pull-k8s-image.sh

./pull-k8s-image.sh k8s.gcr.io/federation-controller-manager-arm64:v1.3.1-beta.1
# 执行如下操作
# docker pull anjia0532/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1
# docker tag anjia0532/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 k8s.gcr.io/federation-controller-manager-arm64:v1.3.1-beta.1
```

Uses/如何拉取新镜像
-------
[创建issues](https://github.com/anjia0532/gcr.io_mirror/issues/new?assignees=&labels=porter&template=gcr-io_porter.md&title=%5BPORTER%5D) ,将自动触发 github actions 进行拉取转推到docker hub

**注意：**

**为了防止被滥用，目前仅仅支持一次同步一个镜像**

**Issues 必须带 `porter` label，** 简单来说就是通过模板创建就没问题，别抖机灵自己瞎弄。

**标题必须为 `[PORTER]镜像名:tag` 的格式，** 例如`[PORTER]k8s.gcr.io/federation-controller-manager-arm64:v1.3.1-beta.1`,`[PORTER]gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1`

issues的内容无所谓，可以为空

可以参考 [已搬运镜像集锦](https://github.com/anjia0532/gcr.io_mirror/issues?q=is%3Aissue+label%3Aporter+)

**注意:**

本项目目前仅支持 `gcr.io` , `k8s.gcr.io` , `registry.k8s.io` , `quay.io`, `ghcr.io` 镜像，其余镜像源可以提 Issues 反馈或者自己 Fork 一份，修改 `rules.yaml`


Fork/分叉代码自行维护
-------

- 必须: <https://github.com/anjia0532/gcr.io_mirror/fork> 点击连接在自己账号下分叉出 `gcr.io_mirror` 项目
- 可选: 修改 [./rules.yaml](./rules.yaml) 增加暂未支持的镜像库
- 在 [./settings/secrets/actions](./settings/secrets/actions) 创建自己的参数

`DOCKER_REGISTRY`: 如果推到 docker hub 为空即可

`DOCKER_NAMESPACE`: 如果推到 docker hub ，则是自己的 docker hub 账号(不带@email部分)，例如我的 anjia0532

`DOCKER_USER`: 如果推到 docker hub,则是 docker hub 账号(不带@email部分)，例如我的 anjia0532

`DOCKER_PASSWORD`: 如果推到 docker hub，则是 docker hub 密码

k8s.gcr.io 和 gcr.io 镜像tags
------
```bash

# k8s.gcr.io
# 可以通过浏览器打开或者curl等打开(需梯子)
# e.g. https://k8s.gcr.io/v2/sig-storage/nfs-subdir-external-provisioner/tags/list
https://k8s.gcr.io/v2/${namespace}/${image}/tags/list

# 也可以直接用浏览打开看 UI 版的(需梯子)
# e.g. web ui https://console.cloud.google.com/gcr/images/k8s-artifacts-prod/us/sig-storage/nfs-subdir-external-provisioner
https://console.cloud.google.com/gcr/images/k8s-artifacts-prod/us/${namespace}/${image}

# gcr.io
# 可以通过浏览器打开或者curl等打开(需梯子)
# e.g. https://gcr.io/v2/gloo-mesh/cert-agent/tags/list 
https://gcr.io/v2/${namespace}/${image}/tags/list

# e.g. web ui https://console.cloud.google.com/gcr/images/etcd-development/global/etcd
# 也可以直接用浏览打开看 UI 版的(需梯子)
https://console.cloud.google.com/gcr/images/${namespace}/global/${image}

# docker hub
# e.g. https://registry.hub.docker.com/v1/repositories/anjia0532/google-containers.sig-storage.nfs-subdir-external-provisioner/tags
https://registry.hub.docker.com/v1/repositories/${namespace}/${image}/tags

```

ReTag anjia0532 images to gcr.io/ 将加速下载的镜像重命名为gcr.io
-------

### 批量拉取并转换镜像

```shell
sudo tee -a img.txt > /dev/null <<EOT
gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
EOT

# chmod +x batch-pull-k8s-image.sh
cat batch-pull-k8s-image.sh
# 代码如下 ↓↓↓
```

```bash
#!/bin/sh

# 替换 gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 为真实 image
# 将会把 gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 转换为 anjia0532/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 并且会拉取他
# k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> anjia0532/google-containers.{image}/{tag}

images=$(cat img.txt)

# 或者 
#images=$(cat <<EOF
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
#EOF
#)

eval $(echo ${images}|
        sed 's/k8s\.gcr\.io/anjia0532\/google-containers/g;s/gcr\.io/anjia0532/g;s/\//\./g;s/ /\n/g;s/anjia0532\./anjia0532\//g' |
        uniq |
        awk '{print "sudo docker pull "$1";"}'
       )

# 下面这段代码将把本地所有的 anjia0532 镜像 (例如 anjia0532/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 )
# 转换成 grc.io 或者 k8s.gcr.io 的镜像 (例如 gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1)
# k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> anjia0532/google-containers.{image}/{tag}

for img in $(sudo docker images --format "{{.Repository}}:{{.Tag}}"| grep "anjia0532"); do
  n=$(echo ${img}| awk -F'[/.:]' '{printf "gcr.io/%s",$2}')
  image=$(echo ${img}| awk -F'[/.:]' '{printf "/%s",$3}')
  tag=$(echo ${img}| awk -F'[:]' '{printf ":%s",$2}')
  sudo docker tag $img "${n}${image}${tag}"
  [[ ${n} == "gcr.io/google-containers" ]] && sudo docker tag $img "k8s.gcr.io${image}${tag}"
done
```

### 拉取并转换单个镜像
```shell
# chmod +x pull-k8s-images.sh
cat pull-k8s-images.sh
# 代码如下 ↓↓↓
```

```shell
#!/bin/sh

k8s_img=$1
mirror_img=$(echo ${k8s_img}|
        sed 's/k8s\.gcr\.io/anjia0532\/google-containers/g;s/gcr\.io/anjia0532/g;s/\//\./g;s/ /\n/g;s/anjia0532\./anjia0532\//g' |
        uniq)

sudo docker pull ${mirror_img}
sudo docker tag ${mirror_img} ${k8s_img}
```

Copyright and License
---

This module is licensed under the BSD license.

Copyright (C) 2017-, by AnJia <anjia0532@gmail.com>.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
