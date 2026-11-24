# OpenWrt main x86_64 云编译

本分支跟进 **OpenWrt 官方 `main` 开发分支**，每次构建均从官方仓库拉取最新源码；同时使用 **turboacc 最新提交**。稳定版本构建请切换到仓库的 [25.12.6 分支](https://github.com/DoroMyAngel/Actions-OpenWrt/tree/25.12.6)。

## 当前构建配置

- 源码：官方仓库 [openwrt/openwrt](https://github.com/openwrt/openwrt) 的 `main` 分支（不是本仓库内固定的 OpenWrt 源码快照）。
- turboacc：每次构建从 [mufeng05/turboacc](https://github.com/mufeng05/turboacc) 的 `main` 分支获取最新脚本和补丁。
- 目标：x86/64，ext4，Legacy BIOS 与 UEFI combined 磁盘镜像。
- LuCI：包含 Web 管理界面及简体中文语言支持。
- 内核配置：BTF、XDP sockets、BBR、Full Cone NAT、软件流量卸载及 CAKE。
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

## 第三方组件

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

本分支会跟随 OpenWrt main 和 turboacc 上游滚动更新，不能保证每次提交都能成功编译；上游内核、firewall4、nftables 或第三方补丁接口变化时，可能需要调整配置。
