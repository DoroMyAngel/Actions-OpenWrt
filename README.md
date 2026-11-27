# OpenWrt main x86_64 云编译

## 项目简介

本分支用于构建基于 OpenWrt 官方开发版的 x86_64 固件，跟踪官方 `main` 分支。防火墙以 OpenWrt 官方 firewall4 和 LuCI 实现为基础，额外集成 [SONiC Fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone) 补丁；不使用 TurboACC，也不移植 LEDE 的第三方防火墙界面或运行状态补丁。

## 源码版本与更新策略

- 上游仓库：[openwrt/openwrt](https://github.com/openwrt/openwrt)。
- 源码版本：官方 `main` 开发分支，编译时获取最新源码。
- 更新检测：每天检查一次 x86 目标实际使用的 Linux 内核版本。
- 自动编译：检测到内核版本变化后，通过 `source-code-update` 事件触发 **OpenWrt Builder**。
- 固件版本：根据本次源码实际选用的内核版本生成 `snapshot-版本号`。

## 当前构建配置

- 目标平台：x86/64，ext4，Legacy BIOS 与 UEFI combined 磁盘镜像。
- LuCI：使用官方 `luci-nginx` 集合，由 `nginx-full` 提供 Web 服务，通过 uWSGI 连接 LuCI；不启用 uHTTPd。包含 Argon 主题及简体中文支持。
- 防火墙：OpenWrt 官方 firewall4 和官方 LuCI 防火墙页面，额外应用 SONiC Fullcone 补丁。
- NAT 与流量卸载：SONiC Fullcone、OpenWrt 原生软件流量卸载；硬件流量卸载默认关闭。
- 内核网络功能：BBR 内核模块、CAKE。
- 虚拟化驱动：virtio-net、virtio-blk、virtio-scsi、e1000/e1000e、AHCI、ATA。
- 代理：PassWall2、sing-box、Xray、Hysteria、geoview、TCPing、V2Ray GeoIP/GeoSite。
- 容器：Docker、Docker Compose、Dockerman。
- 远程接入与证书：Cloudflared、DDNS（Cloudflare）、ACME、FRP、ZeroTier。
- 监控：Netdata、nlbwmon。
- 网络工具：iperf3、tcpdump、nmap、bind-host、smartmontools、ethtool、curl、wget、ip-full、tc-full。
- LuCI 与其他工具：Argon 主题、微信推送、ttyd、WOL、QEMU Guest Agent。
- 微信推送：启用本机硬盘信息检测和远程宿主机信息检测，不启用流量统计。
- KMS：仅编译 vlmcsd 主程序，不编译 LuCI 管理界面或其中文包。
- 其他：procps-ng-watch、rclone，以及 FUSE/MACVLAN 内核模块。

## 防火墙与 SONiC Fullcone

- 防火墙规则生成、LuCI 防火墙页面和流量卸载选项使用 OpenWrt 官方实现。
- SONiC Fullcone 补丁在 feeds 安装后应用，涉及内核、iptables、libnftnl、nftables、firewall4/firewall3 和 LuCI。
- Fullcone 需要同时启用全局 `firewall.@defaults[0].fullcone='1'` 和对应 masquerading zone 的 `fullcone='1'`。首次启动脚本会为所有 `masq='1'` 的 zone 设置该选项。
- 默认启用 OpenWrt 原生软件流量卸载，硬件流量卸载默认关闭，可在官方 LuCI 防火墙页面调整。
- BBR 内核模块已编译，但不提供自定义 TCP CCA 防火墙选项或服务。系统默认拥塞控制由内核决定；需要临时切换时可使用 sysctl。

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

- OpenWrt 官方 feeds 使用本次克隆的官方 `main` 源码树自带配置。
- PassWall2 及其依赖 feeds 使用仓库配置的独立 feed 来源。
- [SONiC Fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone) 补丁通过上游安装脚本集成。
- Argon 主题固定在提交 `076355f33cd762172a67fa06ec6bd2230d9d9e09`。
- 微信推送固定在提交 `e7d4d49b14f3755039cc236130afa7cfc65b1e09`。
- vlmcsd 软件包定义及配置保存在本仓库 `package/vlmcsd`，上游源码固定在 `Wind4/vlmcsd` 提交 `e599080486478e219cd065e141d6de050a450c27`。

第三方 feeds、软件包与 OpenWrt main 的兼容性会随上游变化。工作流会在下载前检查关键软件包是否仍被选中；若包名或 feed 不兼容则提前失败。内核模块必须与本次固件使用同一套内核构建结果，不要从其他版本单独复制安装。

## 手动编译与自动编译

1. 打开仓库的 **Actions** 页面。
2. 选择 **OpenWrt Builder**。
3. 点击 **Run workflow**，确认选择 `main` 分支。
4. 工作流会从官方 OpenWrt `main` 获取源码，并按仓库中的 feeds、`.config` 和自定义脚本进行构建。

自动更新检测工作流按每日计划运行；检测到上游内核版本变化时会自动触发编译。也可以在 Actions 页面手动运行 **Update Checker** 或 **OpenWrt Builder**。

## 固件下载与刷写说明

- 编译成功后，可从对应 Actions 运行记录的 **Artifacts** 下载固件。
- 工作流同时会创建 GitHub Release，版本号使用本次构建生成的 `snapshot-内核版本`。
- 本分支面向 x86_64；刷写前请确认目标设备启动模式（Legacy BIOS/UEFI）、磁盘布局及固件格式，并备份现有配置。

## 注意事项与已知问题

- 本分支跟随 OpenWrt main 和第三方 feeds 滚动更新，不保证每次上游提交都能成功编译。
- 上游内核、firewall4、nftables、LuCI 或第三方补丁接口变化时，可能需要调整配置或补丁。
- 软件包能通过编译前检查不代表运行时功能一定正常；升级后应检查 Web 管理、防火墙、代理和网络连通性。
- 内核模块必须与固件所用内核版本及配置匹配。

## 上游项目与致谢

- [OpenWrt](https://github.com/openwrt/openwrt)
- [SONiC Fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone)
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
