# OpenWrt 25.12.6 x86_64 云编译

本仓库基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 的 GitHub Actions 构建框架，使用 **OpenWrt 官方源码**，不是 LEDE 或 ImmortalWrt。

## 当前构建配置

- 源码：`openwrt/openwrt`
- 版本：`v25.12.6`
- 目标：x86/64（QEMU/KVM 常见虚拟网卡驱动）
- 根文件系统：ext4
- 镜像：Legacy BIOS 与 UEFI 两种 combined 磁盘镜像
- LuCI：包含 Web 管理界面
- Full Cone NAT：turboacc 的 fw4 兼容模式（`firewall.defaults.fullcone=1`，使用 `nft_fullcone` 模块）
- TCP 拥塞控制：编入 CUBIC 与 BBR，首次启动默认 BBR
- dae/daed eBPF 基础：内核内置 BTF（`CONFIG_KERNEL_DEBUG_INFO_BTF`）和 XDP sockets；BTF 由构建链的 pahole/dwarves 生成
- 流量卸载：Linux 原生软件 Flow Offloading
- 不启用：SFE、Fast Classifier、Broadcom Fullcone 模式
- 不添加 helloworld 等额外第三方 feeds

turboacc 集成固定在提交 `ae412f5dffb2199bdd6c0a02a7bcba31ae0e544e`，避免上游分支变化导致构建结果不可复现。

## 启动云编译

1. 打开仓库的 **Actions** 页面。
2. 选择 **OpenWrt Builder**。
3. 点击 **Run workflow** 启动手动构建。
4. 成功后在本次运行的 Artifacts 下载固件；同时会创建 GitHub Release。

BIOS 虚拟机使用 `combined.img.gz`；UEFI 虚拟机使用 `combined-efi.img.gz`。两种镜像都由当前配置生成。

## 重要说明

- 第一次构建先验证官方源码与 turboacc 补丁能否完整编译。
- Full Cone 只影响本机 NAT 行为，不能绕过运营商 CGNAT。
- BBR 主要作用于 TCP，不会直接改变 UDP NAT 穿透能力。
- 构建产物用于 x86_64 虚拟机；刷写前确认虚拟机启动模式并备份现有配置。

## 上游项目

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [turboacc](https://github.com/mufeng05/turboacc)

## 预编译软件包

当前 `25.12.6` 分支在官方 feeds 基础上增加了固定提交的 PassWall2 feeds，并预选以下软件：

- **代理**：PassWall2、sing-box、Xray、Hysteria，以及 geoview、TCPing、V2Ray GeoIP/GeoSite 数据。
- **容器**：Docker、Docker Compose、Dockerman。
- **远程接入与证书**：Cloudflared、DDNS（Cloudflare）、ACME（acme.sh）、FRP、ZeroTier。
- **监控**：Netdata、nlbwmon。
- **网络工具**：iperf3、tcpdump、nmap、bind-host、smartmontools、ethtool、ip-full、tc-full。
- **加速**：保留原 TurboACC、Full Cone NAT、BBR 配置，增加 CAKE。
- **LuCI/其他**：Argon 主题及配置、微信推送、WOL、vlmcsd、QEMU Guest Agent。

PassWall2 feeds 的提交固定在 `feeds.conf.default` 中，避免上游默认分支更新造成构建结果漂移。工作流在 `make defconfig` 后会检查核心软件包是否确实被选中；若 feed 或包名不匹配，会在下载和编译前明确失败，而不是悄悄生成缺包固件。

注意：第三方 feed 与官方 OpenWrt 的兼容性仍需由实际 GitHub Actions 构建验证。内核模块（如 BBR、CAKE、Full Cone）会与本次固件内核一起编译，不要从其他版本单独复制安装。
