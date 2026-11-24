# OpenWrt main x86_64 云编译

本分支用于跟进 **OpenWrt 官方 main 开发分支**，并使用 **turboacc 最新提交**。稳定版本构建请切换到仓库的 [25.12.6 分支](https://github.com/DoroMyAngel/Actions-OpenWrt/tree/25.12.6)。

## 当前构建配置

- 源码：官方仓库 [openwrt/openwrt](https://github.com/openwrt/openwrt) 的 `main` 分支
- turboacc：每次构建从 [mufeng05/turboacc](https://github.com/mufeng05/turboacc) 的 `main` 分支获取最新脚本和补丁
- 目标：x86/64（QEMU/KVM 常见虚拟网卡驱动）
- 根文件系统：ext4
- 镜像：Legacy BIOS 与 UEFI 两种 combined 磁盘镜像
- LuCI：包含 Web 管理界面
- Full Cone NAT：turboacc 的 fw4 兼容模式（`firewall.defaults.fullcone=1`，使用 `nft_fullcone` 模块）
- TCP 拥塞控制：编入 CUBIC 与 BBR，首次启动默认 BBR
- dae/daed eBPF 基础：内核内置 BTF（`CONFIG_KERNEL_DEBUG_INFO_BTF`）和 XDP sockets
- 流量卸载：Linux 原生软件 Flow Offloading
- 不启用：SFE、Fast Classifier、Broadcom Fullcone 模式
- 不添加 helloworld 等额外第三方 feeds

## 启动云编译

1. 打开仓库的 **Actions** 页面。
2. 选择 **OpenWrt Builder**。
3. 点击 **Run workflow**，确认选择 `main` 分支。
4. 成功后在本次运行的 Artifacts 下载固件；同时会创建以 `main-` 开头的 GitHub Release。

## 重要说明

- 本分支跟随两个上游的滚动更新，源码和 turboacc 补丁会变化，不能保证每次提交都能成功编译。
- OpenWrt 内核、firewall4、nftables 或 turboacc 补丁接口变化时，可能需要调整配置或补丁。
- 固定版本、固定 turboacc commit 的可复现构建请使用 `25.12.6` 分支。
- BIOS 虚拟机使用 `combined.img.gz`；UEFI 虚拟机使用 `combined-efi.img.gz`。请以实际构建产物文件名为准。
- Full Cone 只影响本机 NAT 行为，不能绕过运营商 CGNAT。
- BBR 主要作用于 TCP，不会直接改变 UDP NAT 穿透能力。

## 上游项目

- [OpenWrt](https://github.com/openwrt/openwrt)
- [turboacc](https://github.com/mufeng05/turboacc)
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
