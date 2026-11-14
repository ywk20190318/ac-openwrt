***

## 1. 项目信息

- **源码来源**：[VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt.git)
- **设备支持**：Link\_NN6000V2，内核分区 12m（仅构建带 WiFi 驱动的固件版本）
- **固件发布**：[点击下载](https://github.com/wzdddyy/Link_NN6000V2/releases/latest)

***

## 2. 固件配置

### 2.1 系统配置

| 配置项          | 默认值         | 说明                                       |
| ------------ | ----------- | ---------------------------------------- |
| **LAN IP**   | `10.0.0.1`  | (nn6000v2/scripts/update.sh) |
| **WiFi 名称**  | `500/5`     | (nn6000v2/patches/992\_network\_config.sh) |
| **WiFi 状态**  | **启用**      | 首次启动自动启用 2.4G/5G 无线                                |
| **Web 管理服务** | `nginx` | LuCI 由 Nginx 提供服务，移除 uhttpd |
| **2.4G 信道** | `auto` | 自动选择信道 |
| **5G 信道** | `157` | 固定信道 157 |
| **PPPoE 账号** | **未配置**     | (nn6000v2/patches/992\_network\_config.sh)    |
| **PPPoE 状态** | **自动拨号**    | 配置账号密码后自动拨号，无需手动开启                                 |

***

### 2.2 预装插件与应用

| 插件/应用 | 功能说明 |
| --- | --- |
| `luci-theme-argon`、`luci-app-argon-config` | Argon 主题及配置 |
| `luci-app-dockerman` | Docker 管理 |
| `luci-app-mini-diskmanager` | 磁盘管理 |
| `luci-app-quickfile` | 文件管理 |
| `luci-app-p910nd` | USB 打印机共享 |
| `luci-app-hd-idle` | 硬盘休眠 |
***

### 2.3 SONiC FullCone NAT

- IPv4、IPv6 在防火墙常规设置中分别提供独立总开关。
- 每个防火墙区域也分别提供 IPv4、IPv6 开关。
- IPv4 保留上游默认值（全局及 WAN 区域开启）；IPv6 FullCone 全局及 WAN 区域默认关闭。
- 两个协议族的总开关、区域开关和伪装联动分别处理，互不覆盖。
- 使用 ImmortalWrt 上游 fullconenat-sonic 后端包和 luci-app-fullconenat-sonic 管理界面；Linux 6.18 内核、libnftnl、nftables 和 firewall4 补丁由上游提供，后端包通过 Kconfig 启用 CONFIG_NF_NAT_FULLCONE，不使用独立 FullCone kmod。
- 构建会先检查上游后端包、LuCI 包及补丁，并运行内核、libnftnl、nftables、firewall4 和 SONiC LuCI 包的 prepare 阶段检查。

### 2.4 APK 软件源与内核 ABI

普通 APK 软件包源与 kmods 源分开配置。系统从已安装的 kernel APK 元数据读取版本和 vermagic，并从设备读取实际 APK 架构；解析失败时停止生成仓库地址，不猜测 kmods 路径。普通软件包源可通过 APK_MIRROR 覆盖，内核模块源可通过 KMODS_MIRROR 单独覆盖。kmods 必须与当前固件内核 ABI 完全匹配，不能跨内核或跨固件混装。

## 3. 构建方式

- GitHub Actions 仅支持手动触发（`workflow_dispatch`），不会因向 `main` 推送代码自动编译。
- 每次只构建带 WiFi 驱动的固件，不生成 `nowifi` 版本。

## 4. 插件来源

部分插件源自：<https://github.com/kenzok8/openwrt-packages>

***

## 5. 项目结构

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

