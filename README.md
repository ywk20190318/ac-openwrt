# Link NN6000 V2（IPQ60xx）ImmortalWrt 实用精简固件

本分支用于构建 **Link NN6000 V2** 路由器固件。在保留 VIKINGYFY/ImmortalWrt 原有设备支持、NSS、无线和板级驱动的基础上，提供 APK 包管理器、原版 LuCI 简体中文界面、Argon 主题、firewall4/nftables，以及 OpenClash 运行所需的内核模块。

> **状态说明：** 本仓库保存编译配置和构建脚本。本文描述的是预期构建配置；某个版本是否真正包含这些组件，必须以该次 GitHub Actions 编译结果、固件软件包清单（manifest）和设备实测为准。不能仅凭配置文件认定固件已经编译成功。

---

## 1. 设备与源码

| 项目 | 配置 |
|---|---|
| 设备型号 | Link NN6000 V2 |
| OpenWrt 目标 | qualcommax/ipq60xx |
| CPU 架构 | ARM64 / Cortex-A53（aarch64） |
| 上游源码 | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) |
| 上游分支 | main（以设备 INI 配置为准） |
| 设备配置 | nn6000v2/configs/kernel/link_nn6000v2_immwrt.config |
| 构建脚本 | nn6000v2/scripts/build.sh |
| Actions 编译页面 | [NN6000V2 Practical Minimal Build](https://github.com/ywk20190318/ac-openwrt/actions/workflows/main.yml) |

本项目不是通用 IPQ60xx 固件配置。请勿将本分支镜像刷入其他型号设备。

## 2. 默认系统配置

| 配置项 | 默认值 / 状态 | 说明 |
|---|---|---|
| LAN 管理地址 | 10.0.0.1 | 设备定制配置 |
| 2.4GHz Wi-Fi | SSID：500/5 | 首次启动配置为启用 |
| 5GHz Wi-Fi | SSID：500/5 | 首次启动配置为启用 |
| Wi-Fi 密码 | 88888888 | 两个频段使用相同密码 |
| 2.4GHz 信道 | 1 | HT20 |
| 5GHz 信道 | 157 | HE80 |
| 无线国家码 | US | 首次启动脚本设置；请按设备所在地法规确认 |
| PPPoE | 默认不配置 | `main` 工作流可选输入账号和密码；未填写时跳过配置 |
| 连接跟踪上限 | 65535 | 系统支持对应 sysctl 参数时应用 |
| FullCone NAT | 默认启用 | 全局启用，并为所有开启 masquerade 的防火墙区域启用；不保证上级网络一定为 NAT1 |

首次启动无线脚本仅在无线接口尚无有效加密配置时写入默认 SSID 和密码，避免覆盖已有有效无线配置。需要修改无线名称或密码时，请通过 LuCI 无线页面或 UCI 修改。

## 3. 包管理器与基础软件包

### 3.1 APK 包管理器

- 使用 **APK**，配置项为 CONFIG_USE_APK=y。
- 不应启用 OPKG，CONFIG_USE_OPKG 不得为 y。
- 常用命令：

~~~sh
apk update
apk search 软件包名
apk add 软件包名
apk info
~~~

软件源必须与当前固件发行版本、目标架构和内核 ABI 匹配。尤其是内核模块（kmod-*），不能从其他固件版本或其他内核版本的软件源混装。

### 3.2 本分支显式选择的主要用户态软件包

以下是设备配置中明确选择的主要软件包，并非上游目标默认软件包的完整清单。

| 软件包名 | 用途 |
|---|---|
| luci-nginx | 原版 LuCI 管理界面，使用 Nginx/uWSGI 提供 Web 服务 |
| luci-theme-argon | Argon 管理界面主题 |
| firewall4 | 基于 nftables 的防火墙管理 |
| nftables | nftables 用户态工具 |
| nftables-json | nftables JSON 输出支持 |
| luci-app-quickfile / quickfile | QuickFile Web 文件管理器及 Rust 后端 |
| nginx-ssl / nginx-util / nginx-mod-luci / nginx-mod-ubus | QuickFile 所需的 Nginx 反向代理和 LuCI 接入组件 |
| uwsgi / uwsgi-luci-support | Nginx 运行 LuCI 所需组件 |
| block-mount / ntfs3-mount / fuse-utils | 磁盘挂载和文件系统用户态工具 |
| usbutils / sgdisk / resize2fs | USB 与磁盘分区、文件系统维护工具 |

LuCI 简体中文通过 CONFIG_LUCI_LANG_zh_Hans=y 选择，由 LuCI 构建系统生成对应翻译子包；不是把隐藏翻译包当作普通 feed 包单独安装。主 Web 服务采用 luci-nginx，以满足 QuickFile 对 Nginx 反向代理的依赖；Nginx 默认仅监听 HTTP/80。uHTTPd 及其模块在配置和最终 manifest 中均设有禁入检查。Argon 仍作为默认主题。

### 3.3 QuickFile 与外接存储支持

QuickFile 上游包由 LuCI 前端和 Rust 后端组成，前端依赖 `luci-nginx` 与 `quickfile`；上游说明明确要求 Nginx 反向代理。因此本次不是单独塞入一个 LuCI 插件，而是同时编译 Nginx、uWSGI 和 LuCI-Nginx 运行组件。QuickFile 源码固定到上游提交 `ef2ca5d16ad1156539930d8763c3069f6ac4eb12`，避免每次构建自动漂移。

外接磁盘支持包含 USB mass-storage/UAS、USB2/USB3 主机控制器，以及 ext4、FAT/VFAT、exFAT、NTFS3、F2FS、XFS 文件系统模块。另编入 block-mount、NTFS3 挂载工具、USB 识别和分区/文件系统维护工具。是否自动挂载仍由运行时挂载配置决定；编入驱动不等于自动格式化或改动磁盘。

## 4. 内核模块清单

以下模块在设备配置中显式选择。它们属于内核模块包，必须由同一份固件源码、同一次内核构建生成，确保内核版本和 ABI 一致。

| 模块软件包名 | 主要用途 |
|---|---|
| kmod-nft-tproxy | nftables TProxy 透明代理支持 |
| kmod-tun | TUN 虚拟网络设备支持 |
| kmod-nft-fullcone | nftables Full Cone NAT 支持 |
| kmod-nft-bridge | nftables bridge 家族支持 |
| kmod-tcp-bbr | TCP BBR 拥塞控制模块 |
| kmod-netlink-diag | Netlink 诊断支持 |
| kmod-inet-diag | INET socket 诊断支持 |
| kmod-tls | 内核 TLS 支持 |
| kmod-usb-storage / kmod-usb-storage-uas / kmod-usb-storage-extras | USB 大容量存储与 UAS |
| kmod-usb2 / kmod-usb3 / kmod-usb-dwc3 / kmod-usb-xhci-hcd / kmod-usb-ehci / kmod-usb-ohci | USB 主机控制器支持 |
| kmod-fs-ext4 / kmod-fs-vfat / kmod-fs-exfat | 常见 Linux、FAT 与 exFAT 磁盘格式 |
| kmod-fs-ntfs3 / kmod-fs-f2fs / kmod-fs-xfs | NTFS3、F2FS 与 XFS 文件系统 |

### OpenClash 说明

本固件配置预留并要求包含以下模块：

- kmod-nft-tproxy
- kmod-tun

**这不代表固件已经预装 OpenClash。** OpenClash 本体不在当前精简预装列表中。刷入新固件后，只有在软件源提供与当前固件匹配的版本时，才可再通过 APK 安装 OpenClash。

构建脚本会在 make defconfig 后检查上述网络、USB 和文件系统模块是否仍被选中，并在编译完成后检查最终固件 manifest 是否逐一包含所有指定模块。任一检查失败，构建流程应报错退出，避免把缺少模块的镜像当作合格成品发布。

如果运行中的旧固件缺少这些模块，仅修改 GitHub 配置或执行 apk add 并不能补齐与旧内核匹配的模块；需要构建并刷入包含对应模块的新固件。

### KMS 服务说明

如果这里的 KMS 指 Windows/Office 局域网 KMS 服务端（例如 vlmcsd），它是用户态 TCP 服务，不需要额外的专用内核模块。需要的是正常网络协议栈、服务程序本身，以及按需允许 LAN 访问 TCP 1688 端口；若希望客户端自动发现，还需要 dnsmasq 配置对应的 `_vlmcs._tcp` SRV 记录。

因此，本固件不会为了 KMS 增加虚构的 `kmod-kms` 或其他无关内核模块。是否把 `vlmcsd` 服务端和 `luci-app-vlmcsd` 管理界面也编入固件，需另行确认；当前配置不代表已预装这两个软件包。

## 5. 保留与精简策略

### 保留

- VIKINGYFY/ImmortalWrt 原有 NN6000 V2 目标配置。
- 设备所需 NSS、Wi-Fi、IPQ60xx 板级驱动及目标默认软件包。
- 原版 LuCI、Argon 主题、简体中文语言选择。
- firewall4 + nftables。
- 上述显式选择的网络诊断、TCP 和代理相关内核模块。

### 不预装

以下应用或服务不作为本分支默认预装内容：

- OpenClash 本体及其他代理客户端。
- Docker、Dockerman、Podman。
- QuickStart、易有云等非必要服务。QuickFile 与其必需的 Nginx 组件现已纳入本次固件。
- 额外的第三方服务插件、可选应用和存储工具。

精简原则：不为了消除编译警告而强行加入无关应用或依赖。可选功能优先在系统运行后通过匹配的软件源安装；若软件源没有适配包，则不能假定可以直接安装。

## 6. 设备定制与启动脚本

| 文件 | 功能 |
|---|---|
| nn6000v2/patches/991_custom_settings | 调整连接跟踪上限；检查并解除 Dropbear 的 DirectInterface 限制 |
| nn6000v2/patches/992_set-wifi-uci.sh | 首次启动配置 2.4GHz / 5GHz 无线参数和默认 Wi-Fi |
| nn6000v2/patches/993_set_pppoe.sh | PPPoE 账号为占位符时跳过；填写有效账号后才执行配置 |
| nn6000v2/scripts/packages.sh | 安装 luci-nginx、Argon、Nginx/uWSGI，并固定版本拉取 QuickFile 源码 |
| nn6000v2/scripts/feeds.sh | 更新源码默认 feeds；仅单独拉取 QuickFile，不全量安装第三方 feed |
| nn6000v2/scripts/build.sh | 应用设备配置、执行 defconfig、编译、收集镜像并验证 manifest |

## 7. GitHub Actions 编译

进入 [Actions 编译页面](https://github.com/ywk20190318/ac-openwrt/actions/workflows/main.yml)，选择 **Run workflow**。

| 输入项 | 建议值 | 说明 |
|---|---|---|
| kernel_patchver | 留空 | 使用上游源码默认内核版本；只有明确需要覆盖时才填写，例如 6.6 |
| clean_ccache | false | 默认恢复 ccache 和 staging_dir 缓存；设为 true 时跳过缓存恢复并重新建立缓存 |
| pppoe_username | - | 可选：填写宽带账号；留空或填 `-` 则跳过 |
| pppoe_password | - | 可选：填写宽带密码；留空或填 `-` 则跳过 |

工作流仅由 `workflow_dispatch` 手动触发，不会因 push 自动编译。编译流程会执行设备配置检查、APK/中文语言检查、Nginx-only 检查、所需网络/存储模块检查、固件构建和 manifest 检查；缓存覆盖 ccache 与 staging_dir。可选 PPPoE 参数只写入临时构建工作区，不会打印到日志。成功后在该次 Actions 运行对应的 Release 中查看固件文件和中文构建说明。

### 构建成功的判定

不能只看 Actions 是否生成了一个 .bin 文件。至少应确认：

1. Actions 工作流最终状态为成功。
2. 输出目录中存在目标设备固件镜像。
3. 对应 manifest 中存在 QuickFile、Nginx、USB/文件系统模块，以及 kmod-nft-tproxy 和 kmod-tun。
4. 下载后核对镜像文件名、设备型号和构建记录。

## 8. 刷机与升级注意事项

- 刷机前确认设备型号确实为 Link NN6000 V2，并备份配置。
- 不要把 initramfs 测试镜像、factory 镜像和 sysupgrade 镜像混为一谈；应根据镜像类型和设备当前分区/引导方式选择正确刷写路径。
- 是否可以从当前系统通过 LuCI 或 sysupgrade 升级，取决于新旧固件的设备兼容性、分区布局和升级支持，不能仅凭版本号判断。
- 如果涉及包管理器从 OPKG 迁移到 APK、分区布局变化或底层设备配置变化，应优先采用已确认适用于该设备的恢复/刷写方式，不要盲目保留旧配置升级。
- 首次启动后检查 LAN、无线、WAN、SSH、软件源和内核版本。

## 9. 设备运行后核验命令

~~~sh
# 系统与目标信息
cat /etc/openwrt_release
uname -r
apk --print-arch

# 包管理器与软件源
cat /etc/apk/repositories.d/distfeeds.list 2>/dev/null
apk update

# 检查关键软件包
apk info | grep -E '^(luci-nginx|luci-app-quickfile|quickfile|luci-theme-argon|nginx|firewall4|nftables|kmod-nft-tproxy|kmod-tun)'

# 检查内核模块与 TUN 设备
lsmod | grep -E 'tun|nft_tproxy|nft'
test -c /dev/net/tun && echo "TUN 设备存在" || echo "TUN 设备不存在"
~~~

注意：apk --print-arch 只显示 APK 架构，不代表软件源中的内核模块一定与当前内核 ABI 匹配。安装内核模块前，应确认软件源来自当前固件对应的构建版本。

---

## 10. 上游项目与致谢

- [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)
- [原始设备脚本参考项目](https://github.com/ZqinKing/wrt_release)
- [sbwml/luci-app-quickfile](https://github.com/sbwml/luci-app-quickfile)（QuickFile 上游源码，固定提交构建）

本分支针对个人设备配置进行维护。具体软件包版本、内核版本和最终固件内容，以每次实际构建产物为准。
