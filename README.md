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
| **WiFi 密码**  | `88888888` | 无线密码                                     |
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

### 2.3 已移除的 iStore 组件

以下 iStore 商店及其专用辅助包不再安装：

- `luci-app-store`
- `luci-app-istorex`
- `taskd`
- `luci-lib-taskd`
- `luci-lib-xterm`
- `luci-lib-ipkg`

Docker 管理相关组件保留；dockerd 使用上游官方 OpenWrt/ImmortalWrt 软件包，不依赖 iStoreOS fork。

***

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

