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

1. **Mosey 由用户手动安装（13 个 split）**：设备上的 `com.google.android.mosey` 与模块自带 MoseyApp 同为 versionCode 60715，`base.apk` 字节一致（`7ab2deae…`），但 realme 版是 13 个 split（ar/et/fr/iw/ja/kk/ru/uk，且 xxhdpi 哈希不同）。原版 `app-check.sh` 要求恰好 6 个 split，会导致 provider 起不来 —— 已在 r2 修复（见 §7）。
2. **OShare：无需改模块**（2026-11-11 复核）。realme 的 OShare 16.4.60 的 manifest 里**声明了** `com.oplus.oshare.OShareServer`，并且 `am startservice -n com.coloros.oshare/com.oplus.oshare.OShareServer` 实测返回 `Starting service`、`dumpsys activity services` 能看到 ServiceRecord。模块 `receive-session.sh` 使用的组件与设备一致。LSPosed 桥接是 DexKit 语义匹配，待装模块后验证 hook 命中。
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


---

## 7. r2 变更（2026-11-11）：Mosey 分包自适应

**现象**：用户自行安装了 Mosey（Quick Share extension），`pm path` 返回 13 个 split；模块的 `app-check.sh` 要求 active split 数量等于清单行数（6），并逐个比对哈希，于是报 `Active APK split count differs` / `Active APK differs`，provider 无法激活。

**实测对比**：

| 文件 | 模块清单 | 设备实际 | 结果 |
| --- | --- | --- | --- |
| `base.apk` | `7ab2deae…` | `7ab2deae…` | 一致（同一构建） |
| `split_config.arm64_v8a.apk` | `3f7c689c…` | `3f7c689c…` | 一致 |
| `split_config.en.apk` / `es.apk` | `cf362969…` / `00c930af…` | 相同 | 一致 |
| `split_config.xxhdpi.apk` | `ff92800e…` | `81f0ff4c…` | 不同 |
| 其它语言 split | 无 | ar/et/fr/iw/ja/kk/ru/uk | 设备多 8 个 |
| `split_config.zh.apk` | `fe0cf4bc…` | 无 | 设备缺 1 个 |

**结论**：`base.apk` 与 ABI split 一致，说明是同一版 Mosey 的不同 ROM 打包；语言/密度 split 差异不影响代码与原生库。

**修改**：`bin/app-check.sh` 改为只校验 `base.apk`（original / patched 两种哈希）与 `split_config.arm64_v8a.apk`，不再要求 split 数量或语言/密度 split 的哈希；日志改为 `MOSEY_60715_BASE_VERIFIED ... splits=N`。

**产物**：`OPAirDrop-v1.0.31-RMX5010-r2.zip`，SHA256 `8b8147402b703e01fc452cc79718ce888d62334390b0e9fa52590d673cf4f5fd`。

旧版（r1）模块快照保存在仓库的 `old/2026-11-11-r1/`。


---

## 8. r3 变更（2026-11-11 晚）：改用 A 方案（Mosey 用设备现有来源）

真机测试发现 opairshare 自带 `/system_ext/priv-app/MoseyApp` 在 realme 上跑不通：

- app 进程的 mount namespace 看不到 `/system_ext/priv-app/MoseyApp/base.apk` → `Failed to open APK` → 进程崩溃；
- GMS 不发布 `com.google.android.mosey` 模块行（只有 `NearbySharingService / qs_v1`）→ 原 auth 检查必失败；
- root 从后台 `am startservice` 拉 `ExternalSharingService` 被平台拒绝（`Unable to start service ... not found`）；
- SDK 36 没有 `android.permission.ACCESS_LOCAL_NETWORK`，原 `grant-permissions.sh` 会直接 `exit 3`。

**采用方案 A**：Mosey 由设备上已有的 `com.google.android.mosey` KSU 模块（`/system/app`）或用户安装提供，opairshare 只负责驱动与 APK 补丁。

| 文件 | 变更 |
| --- | --- |
| `customize.sh` | 删除 `REPLACE=/system/system_ext/priv-app/MoseyApp`；不再自带 MoseyApp |
| `bin/callback.sh` | `SYSTEM_APK` 改为 `pm path` 得到的 active base，只挂载一个路径 |
| `bin/callback-bootstrap.sh` | 增加 realme 证据（`NearbySharingService` + `qs_v1`）；该路径下不再强拉 provider |
| `bin/grant-permissions.sh` | best-effort，未知权限跳过 |

**实测结果（未重启、手动 `control.sh start`）**：

```
DRIVER_SWAP_DONE → NATIVE_BINDER_READY → AUTH_BEGIN
CALLBACK_AUTH_NO_GMS_EVIDENCE: patching the installed base only
MOSEY_60715_BASE_VERIFIED original splits=13
MOSEY_60715_BASE_VERIFIED patched splits=13
CALLBACK_PATCH_READY r3
CALLBACK_AUTH_PRIMED evidence=none
AIRDROP_RESIDENT_READY_UI_GATED
```

栈状态：`wonder` / `mac80211` / `qca_cld3_peach_v2` / `oneplus13_wonder_provider` 全部加载；117 个驱动参数（98 个 AWDL）；`mosey_server` 运行；`control.sh status` → `stack=stage44_coexist_owned`、Binder service found、Wi-Fi 已连上 5 GHz。

**尚未验证**：AirDrop 实际收发（需要打开 Quick Share / OShare 分享面板触发 provider 与 AWDL 会话）。

产物：`OPAirDrop-v1.0.31-RMX5010-r3.zip`，SHA256 `266707d4b85ba65d62a795fc4ef9e73cba21ff6d333481957e1e232c62b62319`。
旧版（r2）快照见 `old/2026-11-11-r2/`。
