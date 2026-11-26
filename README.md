# OpenWrt main x86_64 云编译

本分支跟进 **OpenWrt 官方 `main` 开发分支**，每次构建均从官方仓库拉取最新源码。防火墙使用 OpenWrt 官方 firewall4/LuCI 实现，仅额外集成 [SONiC Fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone) 补丁；不使用 TurboACC，也不移植 LEDE 的第三方防火墙界面或运行状态补丁。

## 当前构建配置

- 源码：官方仓库 [openwrt/openwrt](https://github.com/openwrt/openwrt) 的 `main` 分支。
- 目标：x86/64，ext4，Legacy BIOS 与 UEFI combined 磁盘镜像。
- LuCI：使用 OpenWrt 官方 `luci-nginx` 集合，由 Nginx 提供 Web 服务，通过 uWSGI 连接 LuCI；不安装 uhttpd。保留 Argon 主题及简体中文语言支持。
- 防火墙：OpenWrt 官方 firewall4、官方 LuCI 防火墙页面 + SONiC Fullcone 补丁。
- NAT/加速：SONiC Fullcone、OpenWrt 原生软件流量卸载；硬件流量卸载默认关闭。
- 内核网络功能：BBR 内核模块、CAKE。
- 虚拟化驱动：virtio-net、virtio-blk、virtio-scsi、e1000/e1000e、AHCI、ATA。
- 代理：PassWall2、sing-box、Xray、Hysteria、geoview、TCPing、V2Ray GeoIP/GeoSite。
- 容器：Docker、Docker Compose、Dockerman。
- 远程接入与证书：Cloudflared、DDNS（Cloudflare）、ACME、FRP、ZeroTier。
- 监控：Netdata、nlbwmon。
- 网络工具：iperf3、tcpdump、nmap、bind-host、smartmontools、ethtool、curl、wget、ip-full、tc-full。
- LuCI/其他：Argon 主题、微信推送、ttyd、WOL、QEMU Guest Agent。
- 微信推送启用本机硬盘信息检测和远程宿主机信息检测，不启用流量统计。
- KMS：仅编译 vlmcsd 主程序，不编译 LuCI 管理界面或其中文包。
- 其他：procps-ng-watch、rclone，以及 FUSE/MACVLAN 内核模块。

## 防火墙与 SONiC Fullcone

- Web 管理：使用 OpenWrt 官方 Nginx + uWSGI + LuCI 集成，不使用 uhttpd。
- 防火墙规则生成、LuCI 防火墙页面和流量卸载选项均使用 OpenWrt 官方实现，不修改官方 `zones.js`。
- SONiC 安装脚本在 feeds 安装完成后应用内核、iptables、libnftnl、nftables、firewall4/firewall3 和 LuCI Fullcone 补丁。
- Fullcone 需要同时开启全局 `firewall.@defaults[0].fullcone='1'` 和对应 masquerading zone 的 `fullcone='1'`。首次启动脚本会为所有 `masq='1'` 的 zone 设置该选项。
- 默认启用 OpenWrt 原生软件流量卸载，硬件流量卸载默认关闭；可在官方 LuCI 防火墙页面调整。
- BBR 内核模块已编译，但不提供自定义 TCP CCA 防火墙选项或服务。系统默认 TCP 拥塞控制仍由内核决定（通常为 CUBIC）；需要手动切换时可使用 `sysctl`。

例如，临时切换到 BBR：

```sh
modprobe tcp_bbr
sysctl -w net.ipv4.tcp_congestion_control=bbr
```

该设置为运行时设置；如需持久化，请使用系统的 sysctl 配置。

## 第三方组件

- SONiC Fullcone 补丁通过上游安装脚本集成：[mufeng05/openwrt-sonic-fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone)。
- PassWall2 feeds 使用独立 feed 配置，跟随其上游分支更新；OpenWrt 官方 feeds 继续使用本次克隆的官方 main 源码树自带配置。
- Argon 主题固定在提交 `076355f33cd762172a67fa06ec6bd2230d9d9e09`。
- 微信推送固定在提交 `e7d4d49b14f3755039cc236130afa7cfc65b1e09`。
- vlmcsd 软件包定义及配置文件保存在本仓库 `package/vlmcsd`，上游源码固定在 `Wind4/vlmcsd` 提交 `e599080486478e219cd065e141d6de050a450c27`。

第三方 feeds、软件包与 OpenWrt 官方 main 的兼容性会随上游变化；工作流会在下载前检查关键软件包是否仍被选中，若包名或 feed 不兼容则提前失败。内核模块必须与本次固件使用同一套内核构建结果，不要从其他版本单独复制安装。

## 启动云编译

1. 打开仓库的 **Actions** 页面。
2. 选择 **OpenWrt Builder**。
3. 点击 **Run workflow**，确认选择 `main` 分支。
4. 成功后从本次运行的 Artifacts 下载固件；同时会创建以 `main-` 开头的 GitHub Release。

本分支会跟随 OpenWrt main 和 SONiC Fullcone 上游滚动更新，不能保证每次提交都能成功编译；上游内核、firewall4、nftables 或第三方补丁接口变化时，可能需要调整配置。
