# OpenWrt 25.12 x86_64 云编译

本分支跟进 **OpenWrt 官方 `openwrt-25.12` 稳定分支**，使用官方源码和官方 firewall4/LuCI 实现；Full Cone NAT 使用 [SONiC Fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone)，不再安装 TurboACC。

## 当前构建配置

- 源码：`openwrt/openwrt` 的 `openwrt-25.12` 分支；更新检测跟踪 `v25.12.6`。
- 目标：x86/64，ext4，Legacy BIOS 与 UEFI combined 磁盘镜像。
- LuCI：保留本分支的官方 LuCI + SSL 配置。
- 防火墙：OpenWrt 官方 firewall4 和官方 LuCI 防火墙页面，仅额外应用 SONiC Fullcone 补丁。
- NAT/加速：SONiC Fullcone、OpenWrt 原生软件流量卸载；硬件流量卸载默认关闭。
- 内核网络功能：BBR 内核模块、CAKE；不使用 TurboACC、SFE 或 Fast Classifier。
- dae/daed eBPF 基础：内核内置 BTF（`CONFIG_KERNEL_DEBUG_INFO_BTF`）和 XDP sockets。
- 虚拟化：virtio-net、virtio-blk、virtio-scsi、e1000/e1000e、AHCI、ATA。
- 代理：PassWall2、sing-box、Xray、Hysteria、geoview、TCPing、V2Ray GeoIP/GeoSite。
- 容器：Docker、Docker Compose、Dockerman。
- 远程接入与证书：Cloudflared、DDNS（Cloudflare）、ACME、FRP、ZeroTier。
- 监控：Netdata、nlbwmon。
- 网络工具：iperf3、tcpdump、nmap、bind-host、smartmontools、ethtool、curl、wget、ip-full、tc-full。
- LuCI/其他：Argon 主题、微信推送、ttyd、WOL、QEMU Guest Agent、vlmcsd。
- 微信推送启用本机硬盘信息检测和远程宿主机信息检测，不启用流量统计。

## 防火墙与 SONiC Fullcone

- SONiC 安装脚本在 feeds 安装完成后应用内核、libnftnl、nftables、firewall4 和 LuCI Fullcone 补丁。
- 首次启动脚本为全局 firewall defaults 和所有启用 masquerading 的 zone 设置 Fullcone。
- 默认启用 OpenWrt 原生软件流量卸载，硬件流量卸载保持关闭。
- 不再安装 TurboACC，也不使用其 Fullcone 模块或相关配置项。
- BBR 内核模块已编译；TCP 拥塞控制可按需通过 sysctl 设置，不附带自定义 TCP CCA 服务。

例如，临时切换到 BBR：

```sh
modprobe tcp_bbr
sysctl -w net.ipv4.tcp_congestion_control=bbr
```

该设置为运行时设置；如需持久化，请使用系统的 sysctl 配置。

## 启动云编译

1. 打开仓库的 **Actions** 页面。
2. 选择 **OpenWrt Builder**。
3. 点击 **Run workflow**，选择 `openwrt-25.12` 分支。
4. 成功后从本次运行的 Artifacts 下载固件；同时会创建 GitHub Release。
5. 上游检测工作流每 6 小时检查一次 `v25.12.6`；发现新提交后触发编译并发送 Telegram 通知。

BIOS 虚拟机使用 `combined.img.gz`；UEFI 虚拟机使用 `combined-efi.img.gz`。刷写前请确认虚拟机启动模式并备份现有配置。

## 预编译软件包与 feeds

- 官方 packages、luci、routing、telephony feeds 跟随 `openwrt-25.12`；video feed 使用其默认分支。
- PassWall2 的 `openwrt-passwall2` 和 `openwrt-passwall-packages` feeds 跟随各自上游 `main` 分支。
- Argon 主题固定在提交 `076355f33cd762172a67fa06ec6bd2230d9d9e09`。
- 微信推送固定在提交 `e7d4d49b14f3755039cc236130afa7cfc65b1e09`。
- `vlmcsd` 软件包定义及配置保存在本仓库 `package/vlmcsd`，只编译主程序，不编译 LuCI 管理界面或中文包。

工作流会在编译前检查关键软件包、SONiC Fullcone 补丁和配置是否存在；若 feed 或补丁不兼容，会提前失败。第三方 feeds、软件包与 OpenWrt 25.12 的兼容性仍需由实际 GitHub Actions 构建验证。内核模块必须与本次固件使用同一套内核构建结果，不要从其他版本单独复制安装。

## 上游项目

- [OpenWrt](https://github.com/openwrt/openwrt)
- [SONiC Fullcone](https://github.com/mufeng05/openwrt-sonic-fullcone)
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
