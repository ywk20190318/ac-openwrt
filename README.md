***

## 1. 项目信息

- **源码来源**：[VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt.git)
- **设备支持**：Link\_NN6000V2，内核分区 12 MiB（仅构建带 WiFi 驱动的固件版本）
- **固件发布**：[点击下载](https://github.com/wzdddyy/Link_NN6000V2/releases/latest)

***

## 2. 固件配置

### 2.1 系统配置

| 配置项          | 默认值         | 说明                                       |
| ------------ | ----------- | ---------------------------------------- |
| **LAN IP**   | `10.0.0.1`  | (nn6000v2/scripts/update.sh) |
| **WiFi 名称**  | `500/5`     | (nn6000v2/patches/992\_network\_config.sh) |
| **WiFi 密码**  | `88888888` | 2.4G/5G 默认无线密码 |
| **WiFi 状态**  | **启用**      | 首次启动自动启用 2.4G/5G 无线                                |
| **Web 管理服务** | `nginx` | LuCI 由 Nginx 提供服务，移除 uhttpd |
| **2.4G 信道** | `auto` | 自动选择信道 |
| **5G 信道** | `157` | 固定信道 157 |
| **PPPoE 账号** | **未配置**     | (nn6000v2/patches/992\_network\_config.sh)    |
| **PPPoE 状态** | **自动拨号**    | 配置账号密码后自动拨号，无需手动开启                                 |

***

### 2.2 固件内置与后期安装

固件只内置设备启动、无线联网、基础路由、防火墙、DNS、Web 管理和 SONiC FullCone 所必需的组件。可选驱动、文件系统、诊断工具及 LuCI 应用以独立 APK 形式构建，不预装到 rootfs。

**固件内置：**
- NN6000V2 必需的 Qualcomm/NSS、以太网及 Wi-Fi 驱动和对应固件。
- fw4/nftables、基础 NAT/连接跟踪、IPv6 基础协议栈。
- SONiC FullCone 后端及 LuCI 管理页面。
- dnsmasq-full、LuCI、Nginx、uWSGI、SSH 和基础系统组件。
- 设备监控所需的 autocore。

**后期安装（独立 APK，不占用出厂固件空间）：**
- USB 存储、打印机、串口、4G/5G 网卡及 USB 网卡驱动。
- exFAT、VFAT、EXT4、NTFS3、CIFS、NFS 等可选文件系统。
- 可选 IPv6 iptables 兼容层、隧道和路由模块。
- WireGuard 内核模块、命令行工具及 LuCI 协议页面（按需安装）。
- tcpdump、mtr、iperf3、htop、ethtool、curl、磁盘工具等诊断/维护工具。
- QuickFile、磁盘管理、硬盘休眠、打印机管理、Argon 主题等可选 LuCI 应用。

上述后期安装包仍由当前固件对应的构建流程生成；内核模块 APK 必须与设备当前运行的内核 ABI 完全匹配。Docker、dockerd、Dockerman、iStoreOS 商店及不需要的插件不纳入本项目固件和构建配置。
***

### 2.3 SONiC FullCone NAT

- IPv4、IPv6 在防火墙常规设置中分别提供独立总开关。
- 每个防火墙区域也分别提供 IPv4、IPv6 开关。
- IPv4 保留上游默认值（全局及 WAN 区域开启）；IPv6 FullCone 全局及 WAN 区域默认关闭。
- 两个协议族的总开关、区域开关和伪装联动分别处理，互不覆盖。
- 为避免与该 FullCone 后端冲突，软件/硬件流量卸载默认关闭，LuCI 不提供重新开启入口。
- 使用 ImmortalWrt 上游 fullconenat-sonic 后端包和 luci-app-fullconenat-sonic 管理界面；Linux 6.18 内核、libnftnl、nftables 和 firewall4 补丁由上游提供，后端包通过 Kconfig 启用 CONFIG_NF_NAT_FULLCONE，不使用独立 FullCone kmod。
- 构建会先检查上游后端包、LuCI 包及补丁，并运行内核、libnftnl、nftables、firewall4 和 SONiC LuCI 包的 prepare 阶段检查。

### 2.4 APK 软件源与内核 ABI

普通 APK 软件包源与 kmods 源分开配置。系统从已安装的 kernel APK 元数据读取版本和 vermagic，并从设备读取实际 APK 架构；解析失败时停止生成仓库地址，不猜测 kmods 路径。普通软件包源可通过 APK_MIRROR 覆盖，内核模块源可通过 KMODS_MIRROR 单独覆盖。kmods 必须与当前固件内核 ABI 完全匹配，不能跨内核或跨固件混装。


### 后期 APK 清单（按当前配置）

当前配置共选择 **96 个**后期安装包（`=m`）。这些包不预装进固件；内核模块只能安装到 ABI 完全匹配的同一固件/内核上。清单由配置文件自动对应，后续调整配置时应同步更新本节。

**nftables 与网络扩展（24）**

`kmod-nft-offload`、`kmod-nft-bridge`、`kmod-nft-queue`、`kmod-nft-netdev`、`kmod-nf-ipt6`、`kmod-ip6tables`、`kmod-ip6tables-extra`、`kmod-ip6-tunnel`、`kmod-sit`、`kmod-fou`、`kmod-fou6`、`kmod-ipsec6`、`kmod-ip6-vti`、`kmod-xfrm-interface`、`kmod-tcp-bbr`、`kmod-veth`、`kmod-bonding`、`kmod-dsa`、`kmod-netlink-diag`、`kmod-inet-diag`、`kmod-tls`、`kmod-tun`

**文件系统（6）**

`kmod-fs-exfat`、`kmod-fs-vfat`、`kmod-fs-ext4`、`kmod-fs-ntfs3`、`kmod-fs-cifs`、`kmod-fs-nfs`

**USB 驱动及蜂窝网络（36）**

`kmod-usb-acm`、`kmod-usb-ehci`、`kmod-usb-ohci`、`kmod-usb-serial-qualcomm`、`kmod-usb-serial-option`、`kmod-usb-serial-wwan`、`kmod-usb-storage`、`kmod-usb-storage-extras`、`kmod-usb-storage-uas`、`kmod-usb2`、`kmod-usb3`、`kmod-usb-dwc3`、`kmod-usb-xhci-hcd`、`kmod-usb-printer`、`kmod-usb-net`、`kmod-usb-net-cdc-ncm`、`kmod-usb-net-huawei-cdc-ncm`、`kmod-usb-net-cdc-ether`、`kmod-usb-net-qmi-wwan`、`uqmi`、`libqmi`、`luci-proto-qmi`、`umbim`、`libmbim`、`luci-proto-mbim`、`kmod-usb-net-cdc-mbim`、`kmod-usb-net-rndis`、`kmod-usb-net-rtl8150`、`kmod-usb-net-rtl8152`、`kmod-usb-net-asix`、`kmod-usb-net-asix-ax88179`、`kmod-usb-net-cdc-eem`、`kmod-usb-net-cdc-subset`、`kmod-usb-net-ipheth`、`kmod-usb-net-sierrawireless`、`usb-modeswitch`

**WireGuard 与 LuCI 协议（4）**

`luci-proto-relay`、`kmod-wireguard`、`wireguard-tools`、`luci-proto-wireguard`

**命令行维护工具（22）**

`rng-tools`、`blkid`、`htop`、`fuse-utils`、`ntfs3-mount`、`openssh-sftp-server`、`tcpdump`、`curl`、`wget`、`mtr`、`socat`、`iperf3`、`ethtool`、`sgdisk`、`openssl-util`、`resize2fs`、`qrencode`、`smartmontools-drivedb`、`usbutils`、`xz-utils`、`bash`、`ipset`

**可选 LuCI 应用与主题（6）**

`luci-app-quickfile`、`luci-app-mini-diskmanager`、`luci-app-hd-idle`、`luci-app-p910nd`、`luci-theme-argon`、`luci-app-argon-config`

## 3. 构建方式

- GitHub Actions 仅支持手动触发（`workflow_dispatch`），不会因向 `main` 推送代码自动编译。
- 手动触发时可选择 `preflight_only`，先运行脚本语法、配置、内核补丁及 FullCone/LuCI prepare 检查，不执行完整编译。
- 每次只构建带 WiFi 驱动的固件，不生成 `nowifi` 版本。

### 视频桌面软件源排除

路由器固件不使用 Wayland、Weston、Qt5/Qt6、SDL、Vulkan、桌面游戏及相关图形栈，因此构建时不启用上游 `video` feed。这样可以避免无关的图形软件依赖和 Qt Kconfig 递归依赖。未使用的 `fwknopd` / `luci-app-fwknopd` 与 `squeezelite` feed 包也从构建包树中排除，避免其已知的递归 Kconfig 选项干扰配置生成。

文件系统方面：OverlayFS 和 SquashFS 由目标内核直接内置，不是独立的 `kmod-fs-overlay` 软件包；F2FS 仍作为固件内置内核模块保留。


### 虚拟网络设备清理

固件构建时从 Qualcomm 默认包列表中移除 NSS GRE/EoGRE 管理模块，并禁用 Dummy、GRE、GRE6、Docker 与 Dockerman 相关包，避免默认创建 `dummy0`、`erspan0`、`docker0`。普通 Linux bridge、设备 LAN/WAN、IPv4/IPv6 基础网络和 SONiC FullCone 保留。


## 4. 已排除的插件与服务

以下项目不进入固件，也不作为本设备的默认插件方案：

| 类别 | 排除项目 |
|---|---|
| 代理/翻墙插件 | Passwall、Passwall2 |
| DNS/过滤插件 | SmartDNS、AdGuardHome |
| 组网/VPN 服务 | Tailscale、ZeroTier |
| 其他网络/管理插件 | Lucky、OpenAppFilter（OAF）、SQM |
| 第三方工具/商店 | GHBoost、QuickStart、iStoreOS 商店及相关 taskd 组件 |
| 容器 | Docker、dockerd、Dockerman 及 Docker 依赖 |

QuickFile、磁盘管理、硬盘休眠、打印机管理和 Argon 主题属于可选 LuCI 应用，不预装固件；若需要，可从匹配当前固件的软件源安装。它们不等同于上表排除的插件服务。

## 5. 软件包来源

本项目保留上游 feeds 作为可选 APK 的构建来源，但不会因此将所有 feed 包装入固件。

***

## 6. 项目结构

```
Link_NN6000V2/
└── nn6000v2/              # 设备专用目录
    ├── configs/           # 固件配置文件目录
    ├── patches/           # 设备补丁目录
    │   ├── cpuusage       # CPU 使用率补丁
    │   ├── hnatusage      # HNA 使用率补丁
    │   ├── smp_affinity   # SMP 中断平衡补丁
    │   └── tempinfo       # 温度信息补丁
    └── scripts/           # 编译脚本目录
        ├── build.sh       # 编译脚本
        ├── feeds.sh       # feeds 配置脚本
        ├── general.sh     # 通用设置脚本
        ├── packages.sh    # 包管理脚本
        ├── system.sh      # 系统配置脚本
        └── update.sh      # 更新脚本
```

