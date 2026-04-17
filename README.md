***

## 1. 项目信息

- **原脚本仓库**：<https://github.com/ZqinKing/wrt_release.git>
- **源码来源**：<https://github.com/VIKINGYFY/immortalwrt.git> - main
- **设备支持**：Link\_NN6000V2,内核分区12m

***

## 2. 固件配置

### 2.1 系统配置

| 配置项          | 默认值         | 说明                                       |
| ------------ | ----------- | ---------------------------------------- |
| **LAN IP**   | `10.0.0.1`  | (nn6000v2/patches/991\_custom\_settings) |
| **WiFi 名称**  | `500/5`     | (nn6000v2/patches/992\_set-wifi-uci.sh)  |
| **WiFi 密码**  | `88888888` | 无线密码                                     |
| **WiFi 状态**  | **禁用**      | 首次启动需手动开启                                |
| **PPPoE 账号** | **未配置**     | (nn6000v2/patches/993\_set\_pppoe.sh)    |
| **PPPoE 状态** | **自动拨号**    | 首次启动自动配置                                 |

***


***

## 3. 插件来源

部分插件源自：<https://github.com/kenzok8/openwrt-packages>

***

## 4. 项目结构

```
Link_NN6000V2/
└── nn6000v2/              # 设备专用目录
    ├── patches/           # 设备补丁目录
    │   ├── cpuusage       # CPU使用率补丁
    │   └── tempinfo       # 温度信息补丁
    └── scripts/           # 编译脚本目录
        ├── build.sh       # 编译脚本
        └── feeds.sh       # feeds配置脚本
```

***

## ImmortalWrt

<div align="center">

![ImmortalWrt](immortalwrt.png)

</div>

***

