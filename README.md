# Link NN6000 V2「精简固件」

本分支用于 **Link NN6000 V2**。目标是精简预装应用，而不是削减设备驱动或内核能力：

- 同步参考项目 `wzdddyy/Link_NN6000V2` 的设备配置和内核模块选择。
- 保留上游设备驱动、Wi-Fi/NSS、文件系统、USB、网络、VPN 等内核模块及 Kconfig 自动依赖。
- 删除所有第三方 LuCI 应用插件的预装选择；不在构建过程中额外克隆或安装插件仓库。
- 保留基础 LuCI 管理界面、Argon 主题和协议配置组件。
- 插件默认不安装；以后按实际需求选择加入构建，或在系统运行后从匹配的软件源安装。

> **重要：** “不预装插件”不等于删除插件的依赖。插件所需的用户态依赖由其软件包 Makefile 声明；内核模块依赖由 Kconfig/package metadata 解析。当前固件会保留参考配置明确选择的全部 kmod，并在编译后逐项核对固件 manifest。

## 1. 源码与设备

| 项目 | 配置 |
|---|---|
| 设备 | Link NN6000 V2 |
| OpenWrt target | qualcommax / ipq60xx |
| 架构 | ARM64 / aarch64 |
| 固件源码 | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) |
| 设备配置参考 | [wzdddyy/Link_NN6000V2](https://github.com/wzdddyy/Link_NN6000V2) |
| 本分支 | [ac-openwrt / 精简固件](https://github.com/ywk20190318/ac-openwrt/tree/%E7%B2%BE%E7%AE%80%E5%9B%BA%E4%BB%B6) |
| 构建配置 | `nn6000v2/configs/kernel/link_nn6000v2_immwrt.config` |
| 构建脚本 | `nn6000v2/scripts/build.sh` |
| feeds 配置脚本 | `nn6000v2/scripts/feeds.sh` |
| 插件包接入脚本 | `nn6000v2/scripts/packages.sh` |

## 2. 精简策略

### 保留

- NN6000 V2 设备专用配置、板级驱动和设备固件定义。
- 参考配置中明确选择的全部内核模块（当前配置统计为 **75 项显式 kmod 选择**）。
- kmod 的 Kconfig/package 依赖；由 `make defconfig` 自动解析，不手工删减依赖。
- 上游配置中的非插件基础软件包、USB/Modem 支持、文件系统支持、网络工具和 VPN 协议组件。
- APK 包管理器。
- 原版 LuCI 管理界面、Argon 主题、简体中文语言选择。
- firewall4/nftables 基础防火墙配置。

### 不预装

- iStoreOS / iStoreX / `istore` / `istorex` / `luci-app-istore` / `luci-app-istorex` / `luci-app-store`：明确禁用，不加入固件；构建脚本会在 Kconfig 解析后和最终 manifest 阶段双重检查。

- 所有 `luci-app-*` 应用插件。
- Docker/Dockerman、代理服务、广告过滤、网络加速、磁盘管理、文件共享、远程组网等可选服务应用。
- 构建时不额外注入第三方插件 feeds，不克隆第三方插件源码，也不批量安装第三方 feed 中的全部软件包。

### 名词区别

- **内核模块**：例如 `kmod-usb-storage`、`kmod-fs-ext4`、`kmod-nft-tproxy`。本分支保留参考配置中选择的项目。
- **协议组件**：例如 `luci-proto-qmi`、`luci-proto-wireguard`，用于网络协议配置，不属于 `luci-app-*` 服务插件，按上游配置保留。
- **LuCI 应用插件**：以 `luci-app-` 开头，本分支不预装。
- **主题**：`luci-theme-argon` 是界面主题，不是服务插件；当前仍保留。若希望连主题也移除，可单独调整配置。

## 3. 插件清单（参考上游仓库可查到的项目）

下面列出参考项目配置文件、插件安装脚本和 README 中能够查到的插件/应用。**清单仅供选择，不代表当前精简固件已安装。** 个别项目的实际包名可能随 feed 更新而变化，添加前请以对应仓库 Makefile 为准。

| 插件 / 软件包 | 用途 | 当前状态 |
|---|---|---|
| `luci-app-quickfile` / `quickfile` | 文件管理 | 不预装 |
| `luci-app-dockerman` / `dockerd` / `luci-lib-docker` | Docker 管理及运行时 | 不预装 |
| `luci-app-lucky` / `lucky` | Lucky 网络工具 | 不预装 |
| `luci-app-oaf` / `oaf` / `open-app-filter` | 应用过滤 | 不预装 |
| `luci-app-pbr` / `pbr` | 策略路由 | 不预装 |
| `luci-app-ttyd` | Web 终端 | 不预装 |
| `luci-app-upnp` | UPnP 端口映射 | 不预装 |
| `luci-app-adguardhome` / `AdGuardHome` | DNS 广告过滤 | 不预装 |
| `luci-app-ghboost` / `ghboost` | GitHub 加速 | 不预装 |
| `luci-app-mini-diskmanager` | 磁盘管理 | 不预装 |
| `luci-app-hd-idle` | 硬盘休眠 | 不预装 |
| `luci-app-p910nd` / `p910nd` | 打印机服务 | 不预装 |
| `luci-app-smartdns` / `smartdns` | DNS 转发与缓存 | 不预装 |
| `luci-app-samba4` / `samba4` | SMB 文件共享 | 不预装 |
| `luci-app-autoreboot` | 定时重启 | 不预装 |
| `luci-app-sqm` / `sqm-scripts` | SQM 流量管理 | 不预装 |
| `luci-app-tailscale-community` / `tailscale` | Tailscale 组网 | 不预装 |
| `luci-app-zerotier` / `zerotier` | ZeroTier 组网 | 不预装 |
| `luci-app-passwall` | PassWall 代理管理 | 不预装 |
| `luci-app-wireguard` | WireGuard 管理界面 | 不预装；WireGuard 内核/工具组件保留 |
| `luci-app-argon-config` | Argon 主题配置 | 不预装；Argon 主题本身保留 |
| `luci-app-quickstart` / `quickstart` | 快速配置 | 不预装 |
| `luci-app-sing-box`（如所用 feed 提供）/ `sing-box` | sing-box 代理核心及管理界面 | 不预装；当前仅参考脚本曾更新核心源码，未列入精简预装 |

### 插件来源线索

参考项目曾使用或提及以下来源。上游仓库内容可能变化，添加前请检查包名、分支、依赖和许可证：

| 来源 | 主要对应项目 |
|---|---|
| [kenzok8/openwrt-packages](https://github.com/kenzok8/openwrt-packages) | QuickStart、SmartDNS、Argon、Lucky、AdGuardHome、Dockerman、QuickFile、Mini Disk Manager、GHBoost、OAF、Tailscale、ZeroTier 等（本分支不接入该第三方 feed） |
| [OpenWrt-Passwall/openwrt-passwall](https://github.com/Openwrt-Passwall/openwrt-passwall) | PassWall LuCI 插件 |
| [OpenWrt-Passwall/openwrt-passwall-packages](https://github.com/Openwrt-Passwall/openwrt-passwall-packages) | PassWall 相关依赖包 |
| [gdy666/luci-app-lucky](https://github.com/gdy666/luci-app-lucky) | Lucky |
| [wzdddyy/luci-app-adguardhome](https://github.com/wzdddyy/luci-app-adguardhome) | AdGuardHome LuCI 插件 |
| [pymumu/luci-app-smartdns](https://github.com/pymumu/luci-app-smartdns) | SmartDNS LuCI 插件 |
| [sbwml/luci-app-quickfile](https://github.com/sbwml/luci-app-quickfile) | QuickFile |
| [4IceG/luci-app-mini-diskmanager](https://github.com/4IceG/luci-app-mini-diskmanager) | Mini Disk Manager |
| [lisaac/luci-app-dockerman](https://github.com/lisaac/luci-app-dockerman) | Dockerman |
| [destan19/OpenAppFilter](https://github.com/destan19/OpenAppFilter) | OAF |
| [Tokisaki-Galaxy/luci-app-tailscale-community](https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community) | Tailscale LuCI 插件 |
| [aimeeacker/luci-app-zerotier](https://github.com/aimeeacker/luci-app-zerotier) | ZeroTier LuCI 插件 |

## 4. 以后需要插件，应该在哪里添加

当前构建默认不接入第三方插件源。需要某个插件时，按下面流程单独添加，不要一次性恢复全部插件。

### A. 添加软件源

编辑：

```
nn6000v2/scripts/feeds.sh
```

在 `update_feeds()` 中添加对应 feed，例如：

```sh
echo "src-git my_plugins https://github.com/组织名/软件包仓库.git;分支名" >> "$feeds_path"
```

`my_plugins` 是 feed 名称，后续安装包时要使用同一个名称。不要把上面示例中的组织名、仓库地址或分支名原样照抄；应替换为插件官方实际仓库。

### B. 安装插件包定义

编辑：

```
nn6000v2/scripts/packages.sh
```

在 `install_luci_base()` 后增加单独安装命令，例如：

```sh
./scripts/feeds install -p my_plugins luci-app-插件包名
```

如果插件不在 feed，而是需要从独立 Git 仓库克隆，则在这个脚本中添加明确的克隆函数，并在安装阶段调用。不要恢复上游“批量安装整个第三方 feed”的做法。

### C. 选择是否编入固件

编辑：

```
nn6000v2/configs/kernel/link_nn6000v2_immwrt.config
```

增加：

```
CONFIG_PACKAGE_luci-app-插件包名=y
```

插件的依赖应由软件包 Makefile 的 `DEPENDS` 声明和 Kconfig 自动解析。不要为了让插件编译通过而随意删除或硬编码其依赖。若插件依赖额外 kmod，应确认对应模块已选中，并通过本分支的构建检查。

### D. 在已刷入的系统中安装

当前分支使用 APK。若软件源已经提供与本固件版本、架构相匹配的插件包，可以在设备上执行：

```sh
apk update
apk search 插件包名
apk add 插件包名
```

若第三方仓库没有提供适配当前 ImmortalWrt 版本的 APK 软件源，则不能只靠 `apk add` 安装。需要先把插件 feed 接入本分支，使用同一份源码和工具链编译出适配包，再安装生成的 APK。

**内核模块特别注意：** `kmod-*` 必须匹配当前运行内核的版本和 ABI。不能从其他固件、其他内核版本或不匹配的软件源安装。若缺少内核模块，通常应重新构建并刷入包含该模块的固件，而不是从网上随便下载一个 kmod。

## 5. 内核模块保留与构建校验

- 设备配置从参考仓库的 `link_nn6000v2_immwrt.config` 同步内核模块选择。
- 另外保留参考仓库 `docker_deps.config` 中声明的内核模块；即使不预装 Docker，也按“保留全部模块”的要求保留这些选择。
- 执行 `make defconfig` 后，逐项核对设备配置中明确选择的 **122 项软件包** 是否全部保留，并检查 Link NN6000 V2 设备 profile、APK 和简体中文选项；发现 Kconfig 静默丢弃任何选项即提前终止，不进入长时间编译。
- 构建脚本从最终 `.config` 自动收集所有 `CONFIG_PACKAGE_kmod-*=y` 项（当前 **75 项**）。
- 编译完成后逐项检查固件 manifest；只要缺少任何一项显式选择的软件包或 kmod，构建即失败，同时检查 QuickStart/iStoreOS 商店包没有混入镜像。

这项校验针对“配置中显式选择的 kmod”。上游 target 默认模块和依赖解析额外带入的模块，也会按源码构建系统处理，不在此处手工枚举。

## 6. 基本系统设置

| 项目 | 当前配置 |
|---|---|
| 包管理器 | APK |
| LuCI | 原版 LuCI |
| 主题 | Argon |
| LuCI 语言 | 简体中文 |
| 防火墙 | firewall4 / nftables |
| LAN 地址 | 10.0.0.1（由本分支首次启动脚本设置） |

软件源必须与当前固件分支和发行版本匹配。不要混用 OpenWrt、ImmortalWrt 或其他第三方固件的软件源。

## 7. 构建

在仓库 Actions 中运行 NN6000 V2 构建工作流，或按现有脚本执行：

建议先在 Actions 中将 **“仅运行源码 feeds、Kconfig 和设备配置预检”** 设为 `true`。该模式会完成源码准备、feeds 更新、`make defconfig` 和全部配置检查，但不会下载完整编译依赖或开始固件编译；预检通过后，再关闭该选项正式编译。

```sh
./nn6000v2/scripts/pre_clone_action.sh link_nn6000v2_immwrt
./nn6000v2/scripts/build.sh link_nn6000v2_immwrt
```

构建成功的判定不仅是生成镜像，还包括：
1. `make defconfig` 后仍启用 APK 和简体中文。
2. 全部显式选择的 kmod 在最终 manifest 中存在。
3. 固件产物和 manifest 均已收集到 `firmware/`。

刷机前确认设备型号、镜像类型和当前分区/引导方式，并备份配置。不要将本固件刷入其他型号设备。

## 8. 参考与致谢

- [wzdddyy/Link_NN6000V2](https://github.com/wzdddyy/Link_NN6000V2)
- [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)
- 上文列出的插件原始仓库及其维护者。

本分支只维护 NN6000 V2 的精简构建配置。插件清单是从参考项目配置、README 和构建脚本整理的可查项目，并不保证每个包在未来仍可用；以插件上游当前 Makefile、feed 分支和依赖声明为准。
