# OpenWrt 25.12 x86_64 云编译

本仓库基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 的 GitHub Actions 构建框架，使用 **OpenWrt 官方源码**，不是 LEDE 或 ImmortalWrt。

## 当前构建配置

- 源码：`openwrt/openwrt`
- 源码分支：`openwrt-25.12`（持续跟随官方 25.12 稳定分支最新提交）
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

turboacc 每次构建从上游 `mufeng05/turboacc` 的 `main` 分支获取最新安装脚本和源码，不固定提交号。

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

当前 `25.12.6` 分支跟随官方 `openwrt-25.12` 源码和对应稳定版 feeds 的最新提交；另外增加跟随上游 `main` 的 PassWall2 feeds，并预选以下软件：

- **代理**：PassWall2、sing-box、Xray、Hysteria，以及 geoview、TCPing、V2Ray GeoIP/GeoSite 数据。
- **容器**：Docker、Docker Compose、Dockerman。
- **远程接入与证书**：Cloudflared、DDNS（Cloudflare）、ACME（acme.sh）、FRP、ZeroTier。
- **监控**：Netdata、nlbwmon。
- **网络工具**：iperf3、tcpdump、nmap、bind-host、smartmontools、ethtool、ip-full、tc-full。
- **加速**：保留原 TurboACC、Full Cone NAT、BBR 配置，增加 CAKE。
- **LuCI/其他**：Argon 主题（配置功能已内置）、微信推送、WOL、QEMU Guest Agent。
- **微信推送可选功能**：启用本机硬盘信息检测和远程宿主机信息检测；明确不启用流量统计（避免与 Flow Offloading、NAT 和代理组件冲突）。远程宿主机信息需在插件中另行配置 SSH 连接信息。
- **KMS 服务端**：仅添加 `vlmcsd` 主程序（ImmortalWrt 软件包定义），不编译 LuCI 管理界面，也不添加其中文语言包。`vlmcsd` 上游源码固定在 `Wind4/vlmcsd` 提交 `e599080486478e219cd065e141d6de050a450c27`，并使用软件包定义中的镜像校验哈希。

Argon 主题每次构建从 `jerrykuku/luci-theme-argon` 默认分支获取最新源码，由工作流直接加入源码树。Argon 3.x 已将配置界面整合进主题包，因此不再单独选择旧的 `luci-app-argon-config` 兼容迁移包；中文翻译仍通过 `luci-i18n-argon-config-zh-cn` 单独提供（前提是该版本 feed 中存在此翻译包）。

PassWall2 的 `openwrt-passwall2` 和 `openwrt-passwall-packages` feeds 跟随各自上游 `main` 分支；官方 packages、luci、routing、telephony feeds 跟随 `openwrt-25.12` 分支。video feed 使用其默认分支。工作流会在 feeds 安装后将仓库内的 `package/vlmcsd` 加入 OpenWrt 源码树，并在 `make defconfig` 后检查 `vlmcsd` 主程序确实被选中，同时确认 LuCI app 和中文语言包未启用；工作流也会检查其他核心软件包是否确实被选中；若 feed 或包名不匹配，会在下载和编译前明确失败，而不是悄悄生成缺包固件。

注意：第三方 feed 与官方 OpenWrt 的兼容性仍需由实际 GitHub Actions 构建验证。内核模块（如 BBR、CAKE、Full Cone）会与本次固件内核一起编译，不要从其他版本单独复制安装。

微信推送源码每次构建从 `tty228/luci-app-wechatpush` 默认分支获取最新版本，由工作流加入源码树；源码包含 `po/zh_Hans/wechatpush.po` 中文翻译。工作流会在 `make defconfig` 后检查插件、中文翻译、本机硬盘检测和远程宿主机检测均已选中，并确保流量统计选项未启用。
