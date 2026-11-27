# OpenWrt 25.12 x86_64 云编译

## 项目简介

本分支用于构建基于 OpenWrt 官方 25.12 稳定版本的 x86_64 固件，跟踪官方 `v25.12.x` 正式稳定版 Tag。防火墙以 OpenWrt 官方 firewall4 和 LuCI 实现为基础，额外集成 [SONiC Fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone) 补丁；不使用 TurboACC，也不移植 LEDE 的第三方防火墙界面或运行状态补丁。

## 源码版本与更新策略

- 上游仓库：[openwrt/openwrt](https://github.com/openwrt/openwrt)。
- 源码版本：官方 `v25.12.x` 正式稳定版 Tag，不跟踪开发分支快照。
- 更新检测：每 6 小时检查一次最新的正式稳定版 Tag（格式为 `v25.12.数字`）。
- 自动编译：发现新稳定版后，工作流通过 `workflow_dispatch` 向本分支的 **OpenWrt Builder** 传入对应 `source_ref`。
- 手动编译：可在运行 **OpenWrt Builder** 时指定 `source_ref`；留空时自动解析当前最新的 25.12 稳定版 Tag。
- 固件版本：使用本次构建对应的稳定版 Tag（去掉前缀 `v`）作为 Release 版本号。

## 当前构建配置

- 目标平台：x86/64，ext4，Legacy BIOS 与 UEFI combined 磁盘镜像。
- LuCI：使用官方 `luci-nginx` 集合，由 `nginx-full` 提供 Web 服务，通过 uWSGI 连接 LuCI；不启用 uHTTPd。包含 Argon 主题及简体中文支持。
- 防火墙：OpenWrt 官方 firewall4 和官方 LuCI 防火墙页面，额外应用 SONiC Fullcone 补丁。
- NAT 与流量卸载：SONiC Fullcone、OpenWrt 原生软件流量卸载；硬件流量卸载默认关闭。
- 内核网络功能：BBR 内核模块、CAKE；启用内核 BTF 和 XDP sockets，为相关 eBPF 应用提供基础支持。
- 虚拟化驱动：virtio-net、virtio-blk、virtio-scsi、e1000/e1000e、AHCI、ATA。
- 代理：PassWall2、sing-box、Xray、Hysteria、geoview、TCPing、V2Ray GeoIP/GeoSite。
- 容器：Docker、Docker Compose、Dockerman。
- 远程接入与证书：Cloudflared、DDNS（Cloudflare）、ACME、FRP、ZeroTier。
- 监控：Netdata、nlbwmon。
- 网络工具：iperf3、tcpdump、nmap、bind-host、smartmontools、ethtool、curl、wget、ip-full、tc-full。
- LuCI 与其他工具：Argon 主题、微信推送、ttyd、WOL、QEMU Guest Agent。
- 微信推送：启用本机硬盘信息检测和远程宿主机信息检测，不启用流量统计。
- KMS：仅编译 vlmcsd 主程序，不编译 LuCI 管理界面或其中文包。

## 防火墙与 SONiC Fullcone

- 防火墙规则生成、LuCI 防火墙页面和流量卸载选项使用 OpenWrt 官方实现。
- SONiC Fullcone 补丁在 feeds 安装后应用，涉及内核、libnftnl、nftables、firewall4 和 LuCI。
- 首次启动脚本为全局 firewall defaults 和所有启用 masquerading 的 zone 设置 Fullcone。
- 默认启用 OpenWrt 原生软件流量卸载，硬件流量卸载默认关闭，可在官方 LuCI 防火墙页面调整。
- 不安装 TurboACC，也不使用其 Fullcone 模块或相关配置项。
- BBR 内核模块已编译；需要切换 TCP 拥塞控制时可按需使用 sysctl。

临时切换到 BBR：

```sh
modprobe tcp_bbr
sysctl -w net.ipv4.tcp_congestion_control=bbr
```

该设置仅在当前运行期间生效；如需持久化，请使用系统的 sysctl 配置。

## LuCI 与 Web 管理

- 使用 `luci-nginx`、`nginx-full`、Nginx LuCI 模块及 `uwsgi-luci-support`。
- 不启用 `uhttpd`、`luci` 默认 Web 服务集合或 `luci-ssl`。
- 不使用 `nginx-ssl`，Web 服务由当前选定的 Nginx 配置提供。
- 编译前会检查关键 Nginx 配置，并确认没有显式启用 uHTTPd。

## 第三方软件包与 feeds

- 官方 packages、luci、routing、telephony feeds 跟随 OpenWrt 25.12；video feed 使用其默认分支。
- PassWall2 的 `openwrt-passwall2` 和 `openwrt-passwall-packages` feeds 跟随各自上游 `main` 分支。
- [SONiC Fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone) 补丁通过上游安装脚本集成。
- Argon 主题固定在提交 `076355f33cd762172a67fa06ec6bd2230d9d9e09`。
- 微信推送固定在提交 `e7d4d49b14f3755039cc236130afa7cfc65b1e09`。
- vlmcsd 软件包定义及配置保存在本仓库 `package/vlmcsd`，只编译主程序，不编译 LuCI 管理界面或中文包。

工作流会在编译前检查关键软件包、SONiC Fullcone 补丁和配置是否存在；若 feed 或补丁不兼容，会提前失败。第三方 feeds、软件包与 OpenWrt 25.12 的兼容性仍需由实际构建验证。内核模块必须与本次固件使用同一套内核构建结果，不要从其他版本单独复制安装。

## 手动编译与自动编译

1. 打开仓库的 **Actions** 页面。
2. 选择 **OpenWrt Builder**。
3. 点击 **Run workflow**，选择 `openwrt-25.12` 分支。
4. 如需指定版本，在 `source_ref` 中填写正式稳定版 Tag，例如 `v25.12.x`；留空则自动选择最新稳定版。
5. 工作流会检出指定 Tag，并按仓库中的 feeds、`.config` 和自定义脚本进行构建。

自动更新检测工作流每 6 小时运行一次；发现新稳定版后会自动触发对应版本的编译。

## 固件下载与刷写说明

- 编译成功后，可从对应 Actions 运行记录的 **Artifacts** 下载固件。
- 工作流同时会创建 GitHub Release，版本号对应本次构建使用的 25.12 稳定版。
- BIOS 虚拟机使用 `combined.img.gz`；UEFI 虚拟机使用 `combined-efi.img.gz`。
- 刷写前请确认目标设备启动模式（Legacy BIOS/UEFI）、磁盘布局及固件格式，并备份现有配置。

## 注意事项与已知问题

- 本分支只跟踪官方 25.12 正式稳定版 Tag，不代表所有第三方 feeds 都有相同的稳定性保证。
- PassWall2 等第三方 feeds 使用各自上游分支，可能独立变化；若包名、依赖或补丁不兼容，编译前检查或构建过程可能失败。
- 软件包能通过编译前检查不代表运行时功能一定正常；升级后应检查 Web 管理、防火墙、代理和网络连通性。
- 内核模块必须与固件所用内核版本及配置匹配。

## 上游项目与致谢

- [OpenWrt](https://github.com/openwrt/openwrt)
- [SONiC Fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone)
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
