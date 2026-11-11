# 已知问题：AWDL native 后端未注册 —— 本方案在 RMX5010 上暂不可用

> 状态：**暂停 / 暂不可用**（2026-11-11）
> 适用：realme GT7 Pro（RMX5010），realme UI `RMX5010_16.0.5.700(CN01)`，Android 16 / SDK 36，内核 `6.6.89-android15-8-g7e1f3c083cc6-abogki467167594-4k`

## 结论

模块可以安装、开机、换入驱动、启动 provider 和 LSPosed 桥接，但 **AWDL 的 native 后端没有注册**，Mosey 退回自己的内部发现（GMS Nearby），AWDL 无线会话从未建立。结果是 iPhone 与手机互相发现不了，**AirDrop 实际不可用**。

## 直接证据

1. LSPosed / Mosey 桥接日志（`rmx5010/logs/awdl-not-registered.txt`）：

```
DISCOVERY_SHARED start internal=true nativeRegistered=0 nativeMode=0 bridgeWanted=1 targets=0
event=discovery_started id=0 status=0
event=advertising_started id=0 status=0
```

`nativeRegistered=0` + `internal=true`：native provider 没注册，发现/广播走的是 Mosey 内部实现，不发 AWDL 帧。

2. 驱动侧一直是空会话：

```
opairshare_channel_state: cookie=0 busy=0 fault=0 error=0 accepting=0 vdev=255 freq=0
opairshare_awdl_rx_mac_filter: used=0 armed=0 pending=0 active=0 fault=0 ... vdev=255
opairshare_bridge_pending: 0
```

3. 没有 `wonder0` / `mosey0` 网卡：

```
/sys/class/ieee80211/wonder   # wiphy 注册成功
ip link | grep wonder         # 无输出（vif 从未创建）
```

4. 实测：iPhone 打开 AirDrop、手机打开“与 iPhone 互传”页面（`com.coloros.oshare/.ui.IOSShareActivity`，显示“正在搜索附近设备…”），双方互相不可见。

## 已确认正常的部分

| 环节 | 状态 / 证据 |
| --- | --- |
| 内核模块 | `wonder` / `mac80211` / `qca_cld3_peach_v2` / `oneplus13_wonder_provider` 全部加载 |
| wonder 绑定 | `Connected to wlan ver 5 (cur: wonder ver 7)`、`minstrel_ht` |
| 驱动参数 | 117 个，98 个 `passthru_*` / `opairshare_*` |
| Quick Share provider | `provider_active=yes`、`foreground_delegate=yes` |
| LSPosed 桥接 | hooks 全部安装（OShare + Mosey 两侧），`DISCOVERY_SHARED`、`RECEIVE_ADVERTISING` 均触发 |
| Mosey 完整性 | `MOSEY_60715_BASE_VERIFIED patched splits=13` |
| 回调补丁 | `callback_owned_this_boot=yes` |
| 分享入口 | 系统分享面板可见“与 iPhone 互传”，可打开 |
| 共存准备 | `COEX_UI_PREPARED frequency=5825 class=cross5g` |

## 推测根因

`mosey_server` 通过 `LD_PRELOAD` 的 `libopairshare_capability.so` / `libopairshare_config.so` / `libopairshare_channel.so` 接管 Mosey 的发现/广播接口。这组库是按 OnePlus 13 的 Mosey 构建适配的；在 realme 这版 Mosey（versionCode 60715、targetSdk 37）上，native provider 没有注册成功（`nativeRegistered=0`），于是 Mosey 用内部发现继续跑。

需要做的是：对照这版 Mosey 的符号/方法签名重新适配 native 层（或找到能让 Mosey 走 native discovery 的调用路径），这不是脚本层能修的。

## 重新开启的条件

至少满足：

1. 桥接日志出现 `nativeRegistered=1`（或等价的 native 注册成功标志）；
2. `opairshare_channel_state` 出现 `accepting=1` 且 `vdev` 不为 255、`freq=5745`；
3. `ip link` 出现 `wonder0` / `mosey0`；
4. 用 iPhone/Mac 实测能互相发现并完成一次收发。

## 复现与取证

```sh
adb shell su -c "sh /data/adb/modules/opairshare/bin/control.sh status"
adb shell su -c "cat /sys/module/qca_cld3_peach_v2/parameters/opairshare_channel_state"
adb shell su -c "ip -o link"
adb shell su -c "tail -n 100 /data/adb/lspd/log/modules_*.log"
```

本目录 `logs/awdl-not-registered.txt` 保存了本次定案的日志摘录。
