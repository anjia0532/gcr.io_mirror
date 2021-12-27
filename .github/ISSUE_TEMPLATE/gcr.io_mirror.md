---
name: New Version
about: 请求构建指定Frida版本
title: "[VERSION]"
labels: version
assignees: ''

---

标题必须为 `[VERSION]版本号` 的格式

issues的内容无所谓，可以为空

以 [https://github.com/frida/frida/tags](https://github.com/frida/frida/tags) 为准,一般类似 `15.1.19` 这样

可以参考 [已有请求编译版本集锦](https://github.com/anjia0532/strongR-frida-android/issues?q=is%3Aissue+label%3Aversion+)

**注意:**

本项目只是提供构建，核心防frida检测都是依赖于 [Git Patch Files](https://github.com/AAAA-Project/Patchs/tree/master/strongR-frida/frida-core)

如果patch失败，请去[Git Patch Files](https://github.com/AAAA-Project/Patchs/tree/master/strongR-frida/frida-core) 提issues，本人无力解决这个问题。

已知问题，因为git的patch是基于文件的，不同版本的patch可能不能通用，意味着可能存在patch成功但是构建的frida运行不了，或者patch成功，但是构建frida失败，或者直接patch失败。

针对这个问题，目前尚无精力完善，可以fork后自行修改或者尝试在本地编译frida。
