# OPAirDrop on realme GT7 Pro (RMX5010) / kernel 6.6.89

本目录是 OPAirDrop v1.0.31 在 **realme GT7 Pro（RMX5010）** 上的移植记录、去门槛补丁与真机验证日志。

> 状态：**内核驱动链路已在真机验证通过**（provider → qca → mac80211 → wonder 全部加载，固件初始化成功，98 个 AWDL 参数可见，Wi-Fi 正常，已回滚原厂驱动）。
> **用户态（Mosey / OShare 桥接）尚未验证**，安装模块并重启这一步还没做，原因见文末「已知缺口」。

---

## 1. 目标设备

| 项目 | 值 |
| --- | --- |
| 机型 | realme GT7 Pro（RMX5010，CN） |
| 系统 | realme UI / ColorOS `RMX5010_16.0.5.700(CN01)`，Android 16，**SDK 36** |
| 平台 | `sun` / SM8750 / `ro.soc.model=SM8750` |
| 内核 | `6.6.89-android15-8-g7e1f3c083cc6-abogki467167594-4k` |
| 页大小 | 4 KB（`CONFIG_ARM64_PAGE_SHIFT=12`） |
| 内核配置 | `PREEMPT=y`、`MODVERSIONS=y`、`MODULE_UNLOAD=y`、`CFI_CLANG=y`、`MODULE_SIG` 未强制 |
| WLAN 驱动 | `qca_cld3_peach_v2`（qcacld `5.2.1.119O`，固件 build `10097fff`） |
| WLAN HAL | `vendor.wifi_hal_legacy`（与 OnePlus 同名，脚本无需改） |
| Root | KernelSU 4.1.3（`u:r:ksu:s0`），LSPosed 已安装 |
| OShare | `com.coloros.oshare` 16.4.60（`/product/priv-app/OShare`） |
| Quick Share / Mosey | **ROM 未预装** `com.google.android.mosey` |

---

## 2. 为什么能跑（静态证据）

用 RMX5010 内核源码 `victor-egg/RMX5010_Kernel` 的 `android/abi_gki_aarch64.stg`（7,778,263 B，8,962 个带 CRC 符号）与 v1.0.31 包内四个 `.ko` 的 `__versions` 逐项比对：

| 模块 | 导入 CRC | 被 RMX5010 ABI 表覆盖 | CRC 相同 | CRC 冲突 |
| --- | ---: | ---: | ---: | ---: |
| `mac80211.ko` | 319 | 215 | 215 | 0 |
| `qca_cld3_peach_v2.ko` | 600 | 437 | 437 | 0 |
| `wonder.ko` | 83 | 66 | 66 | 0 |
| `oneplus13_wonder_provider.ko` | 11 | 11 | 11 | 0 |
| **合计** | **1,013** | **729** | **729** | **0** |

- `module_layout` CRC 双方都是 `0x4e276f37`。
- 模块 vermagic 为 `6.6.118-android15-8-o-4k SMP preempt mod_unload modversions aarch64`；设备 release 为 `6.6.89-android15-8-…-4k`。因为模块带 CRC 且内核 `CONFIG_MODVERSIONS=y`，`same_magic()` 会跳过 release 字符串，只比较 `SMP preempt mod_unload modversions aarch64` —— **逐项一致**。
- 剩余 284 条“表外”导入全部来自厂商模块（`cfg80211`、`mac80211`、`cnss*`、`ipam`、`sched-walt`），需要运行时验证；真机 insmod 已经证明它们全部解析成功。

结论：**不需要重编内核模块，v1.0.31 的预编译驱动可以直接用在 RMX5010 的 6.6.89 上。**

---

## 3. 真机验证结果（详见 `analysis.md` 与 `logs/`）

| 步骤 | 结果 |
| --- | --- |
| 同名 dry-run：`insmod mac80211.ko` / `qca_cld3_peach_v2.ko` | `File exists`（= vermagic + 全量 CRC 通过） |
| `insmod wonder.ko`（原厂 mac80211） | 加载成功，但注册失败 `Failed to select rate control algorithm`（原厂 mac80211 无 RC，符合预期） |
| 真实换入（严格按 `control.sh:282-298` 顺序） | provider → qca（带全套 `passthru_*` 参数）→ mac80211 → wonder **全部 `rc=0`** |
| 固件初始化 | `wma_rx_service_ready_event: Firmware build version : 10097fff`、`OP13NAN: nan_data=1 nan=1 sync_delete=1` |
| 驱动参数 | 117 个参数，其中 98 个 `passthru_*` / `opairshare_*`；`passthru_sta_coexist=3`、`opairshare_channel_state` 存在 |
| Wi-Fi | `Wifi is enabled`，`wlan0` UP |
| 回滚 | `rmmod` 四个模块 + 装回原厂 = 成功，Wi-Fi 恢复 |

---

## 4. 去门槛补丁

上游 v1.0.31 的发布包写死了 `PJZ110` / `SDK37` / 精确 `uname -r` / 原厂模块大小 / 原厂 build-id，RMX5010 会全部撞上。补丁见 [`patches/de-gate.patch`](patches/de-gate.patch)：

1. `customize.sh`：删除型号 / SDK / 内核 / KernelSU / metamodule 五道安装门槛。
2. `bin/control.sh`：`preflight()` 只保留 root 检查；删除原厂模块大小白名单（`12365824` / `1093632`）；把 `STOCK_NOTE_*` 比对放宽为“模块有 build-id”。
3. 重新生成 `SHA256SUMS`（`verify.sh` 安装时会校验）。

生产包构建：

```sh
# 需要把上游 OPAirDrop-v1.0.31.zip 放在同目录
python3 build_rmx_package.py
# -> OPAirDrop-v1.0.31-RMX5010-test.zip
```

安装（KernelSU）：

```sh
adb push OPAirDrop-v1.0.31-RMX5010-test.zip /data/local/tmp/
adb shell su -c "ksud module install /data/local/tmp/OPAirDrop-v1.0.31-RMX5010-test.zip"
# 重启后生效
```

回滚：

```sh
adb shell su -c "ksud module disable opairshare"   # 或 uninstall
# 或运行中：sh /data/adb/modules/opairshare/bin/control.sh stop
adb reboot
```

---

## 5. 已知缺口（安装模块前请先读）

1. **ROM 没有 Quick Share / Mosey**：`com.google.android.mosey` 不存在。模块自带 `MoseyApp`（versionCode 60715，minSdk 36，targetSdk 37），计划通过 `REPLACE=/system/system_ext/priv-app/MoseyApp` 在重启后由系统扫描安装；**尚未验证**。
2. **OShare 16.4.60 没有 `com.oplus.oshare.OShareServer`**：`bin/receive-session.sh:31` 硬编码 `am startservice -n com.coloros.oshare/com.oplus.oshare.OShareServer`，在 realme 上找不到该服务，**后台接收路径预计失败**。发送/分享面板是否可用取决于 LSPosed 桥接能否匹配 realme 的 OShare 版本。
3. **SDK 36 vs 上游验证的 37**：Mosey `minSdk=36` 可安装，但 `targetSdk=37` 在 SDK 36 上运行需要实机验证。
4. **`wonder0` 接口未出现**：手动换入后 `wonder.ko` 加载成功，但没有创建 `wonder0`；可能需要完整模块流程（HAL 启动时序 / provider component 绑定）或后续会话触发。待装模块后复查。
5. 真机测试期间未安装模块、未重启；所有驱动换入均已回滚，设备保持原厂状态。

---

## 6. 目录

```
rmx5010/
├── README.md                 本文件
├── analysis.md               调查/测试过程与判断（思考日志）
├── build_rmx_package.py      去门槛打包脚本
├── patches/de-gate.patch     customize.sh + control.sh 的完整 diff
├── scripts/                  真机取证、dry-run、驱动换入测试脚本
└── logs/                     脱敏后的真机日志（probe / insmod / driver-swap）
```
