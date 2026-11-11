# 移植思考日志：OPAirDrop → RMX5010 / 6.6.89

记录 2026-11-11 在真机 `3B158T…`（RMX5010）上的调查与验证过程。所有命令都在 `scripts/` 里；原始输出在 `logs/`（已脱敏 MAC/序列号/SSID）。

---

## 0. 出发点

上游 `Weverses/OPAirDrop` 的 **发布包**（v1.0.16 / v1.0.31）和 **main 源码** 不是一回事：

- 发布包 `customize.sh:3-7` 硬性要求 `ro.product.model=PJZ110`、`SDK=37`、`uname -r` 精确等于 6.6.118…-4k、KernelSU + metamodule。
- `bin/control.sh:260-261` 还要求原厂 `qca_cld3_peach_v2` 恰好 12,365,824 B、`mac80211` 恰好 1,093,632 B。
- main 分支已改成只查 Oplus 品牌 + `sun` 平台，甚至不看内核版本。

RMX5010 的真实值是 `realme` / `sun` / `6.6.89-android15-8-…-4k` / SDK 36 / 原厂 qca 12,349,440 B —— 也就是说：**品牌和平台能过，型号、SDK、内核、模块大小全部会撞墙**。

但真正的问题不是这些字符串：**预编译的四个 `.ko` 能不能在 realme 的 6.6.89 上加载？** 这才是决定移植可行性的东西。

---

## 1. 静态 ABI：先算，不猜

从 `victor-egg/RMX5010_Kernel`（Makefile 6.6.89）取 `android/abi_gki_aarch64.stg`，解析出 8,962 个带 CRC 的符号，`module_layout = 0x4e276f37`。

再读 v1.0.31 四个 `.ko` 的 `__versions` 导入表：

```
mac80211.ko                  imports=319  covered=215  match=215  diff=0  outside=104
qca_cld3_peach_v2.ko         imports=600  covered=437  match=437  diff=0  outside=163
wonder.ko                    imports=83   covered=66   match=66   diff=0  outside=17
oneplus13_wonder_provider.ko imports=11   covered=11   match=11   diff=0  outside=0
```

- **0 个 CRC 冲突**，`module_layout` 一致。
- vermagic 的 release 部分不同（6.6.118 vs 6.6.89），但两边都是 `SMP preempt mod_unload modversions aarch64`；`same_magic()` 在模块带 CRC 时会跳过 release 字符串，所以 **vermagic 不会成为拒绝理由**。
- 表外 284 条全是厂商模块导出（`cfg80211` 的 `wiphy_*`、`mac80211` 的 `ieee80211_*`、`cnss*`、`ipam`、`sched-walt`），静态无法判定。

这一步的结论：**值得直接试，不需要先重编。**

---

## 2. 低风险 dry-run：利用内核加载顺序

内核 `load_module()` 的顺序是：`check_modinfo()`（vermagic）→ `simplify_symbols()`（符号 CRC）→ `add_unformed_module()`（同名冲突）。

所以当原厂模块还在运行时，`insmod` 一个**同名** `.ko`：

- 若 vermagic/CRC 不过 → 立即报错，运行栈不受影响；
- 若全过 → 报 `File exists`，证明 ABI 兼容。

真机结果（`logs/insmod-dryrun.txt`）：

| 操作 | 结果 | 解读 |
| --- | --- | --- |
| `insmod mac80211.ko` | `File exists` | vermagic + 319 条导入全过 |
| `insmod qca_cld3_peach_v2.ko` | `File exists` | vermagic + 600 条导入全过（含 cfg80211/cnss/ipam/walt） |
| `insmod wonder.ko` | `rc=0`，但 dmesg：`Failed to select rate control algorithm` / `Ret: -2` | 原厂 mac80211 没开 `MAC80211_RC_MINSTREL`（realme `sun_perf.config` 与 OnePlus 相同），所以必须用包内自带的 mac80211 |
| `insmod oneplus13_wonder_provider.ko` | `rc=0` | provider 正常 |

> 这一步同时证明了 `torvalds/linux` 那个顺序假设：同名模块会先做完全部校验，再报 EEXIST。

---

## 3. 第一次真实换入：踩到 provider 顺序

按“先 qca 再 mac80211”的直觉换入，`rmmod` 原厂 qca、`insmod` 我们的 qca，结果：

```
qca_cld3_peach_v2: Unknown symbol cnss_set_vendor_wonder_priv_data (err -2)
```

查 `/proc/kallsyms`：realme 的原厂 `cnss2` **不导出** `cnss_set_vendor_wonder_priv_data`（`grep -c` = 0）。这个符号由包内的 `oneplus13_wonder_provider.ko` 提供。

回头读 `rel131/bin/control.sh:282-298`，真实顺序是：

```
rmmod qca_cld3_peach_v2
insmod oneplus13_wonder_provider.ko      ← 先 provider
insmod qca_cld3_peach_v2.ko <30+ 参数>   ← 再 qca
rmmod mac80211
insmod mac80211.ko
insmod wonder.ko physical_name=wondertap0 virtual_name=wonder0
```

**这是本次移植唯一一个真正的“坑”**：顺序错了就 `Unknown symbol`，但同一套模块按正确顺序就能加载。

---

## 4. 第二次换入：通过

按真实顺序重跑（`logs/driver-swap.txt`）：

| 步骤 | 结果 |
| --- | --- |
| `rmmod` 原厂 qca | `rc=0`，驱动干净 deinit（`Driver De-initialized`） |
| `insmod provider` | `rc=0`，`created qcom,cnss-vendor-wlan-wonder` |
| `insmod qca`（全套 `passthru_*` 参数） | `rc=0`；固件下载完成：`regdb.bin`、`bdwlan.elf`；`Firmware build version : 10097fff`；`OP13NAN: nan_data=1 nan=1 sync_delete=1` |
| `rmmod` 原厂 mac80211 / `insmod` 我们的 | `rc=0` |
| `insmod wonder` | `rc=0`，`wonder_probe(): No DT node, matching provider by name` |
| 起 HAL / 开 Wi-Fi | `Wifi is enabled`，`wlan0` UP（`NO-CARRIER`，因为刚重载还没关联） |
| 参数检查 | 117 个参数，98 个 `passthru_*`/`opairshare_*`；`passthru_native_data_rx=Y`、`passthru_awdl_raw_rx=Y`、`passthru_sta_coexist=3`、`opairshare_channel_state` 存在 |
| 回滚 | 四个 `rmmod` + 原厂 `insmod` 全部成功，Wi-Fi 恢复 |

`OP13NAN: nan_data=1` 这一行很关键：它说明 realme 这版固件**支持 NAN Data**，也就是 AWDL 后端依赖的 NDI 能力在。

**结论：内核侧打通了。** 剩下的问题都在用户态和收尾细节。

---

## 5. 尚未闭环的点

1. **`wonder0` 没有出现**。`wonder.ko` 加载成功、provider 也在，但组件绑定可能依赖 qca（PLD）在特定时机调用 `cnss_set_vendor_wonder_priv_data`，或者依赖 HAL 启动后的时序。手动测试里 `ip link` 没有 `wonder0`/`wondertap0`。这一点需要在装模块后按完整流程复查（`control.sh start` 后 `kernel_matches` 是否通过、`wonder0` 是否创建）。
2. **OShare 版本差异**：realme 的 `com.coloros.oshare` 16.4.60 **没有** `com.oplus.oshare.OShareServer` 类；已有的是 `FileTransferService`、`KeepForeService`、`FeatureActivationService`、`OshareTileService`、`NfcIosServer`、`OshareStateReceiver`。`bin/receive-session.sh:31` 硬编码了前者，后台接收大概率失败，需要改成 realme 的服务名或走 LSPosed 桥接。
3. **Mosey 缺失**：ROM 没有 `com.google.android.mosey`（也没有 `/system/system_ext/priv-app/MoseyApp`）。模块自带 MoseyApp（60715，minSdk 36，targetSdk 37），计划靠 `REPLACE` 在重启后由 PackageManager 扫描安装——未验证。
4. **SDK 36**：上游只在 SDK 37 上验证过；Mosey 的 targetSdk 37 在 36 上行为未知。
5. 全程**没有安装模块、没有重启**；两次驱动换入均已回滚，设备处于原厂状态。

---

## 6. 为什么没有选择重编

| 组件 | 重编可行性 |
| --- | --- |
| `mac80211.ko` / `wonder.ko` / provider | 可以（RMX5010 common 源码 + 项目 wonder/provider 源码） |
| `qca_cld3_peach_v2.ko` | **不行**：realme 没有公开 `vendor/qcom/opensource/wlan`；`victor-egg/RMX5010_Kernel` 只有 common/msm-kernel，OnePlusOSS 的 manifest 也只有 `oneplus/*` 分支 |

而静默 ABI 对比 + 真机换入已经证明**不需要重编**，重编只会引入新的风险（驱动源码版本与 realme 固件不匹配）。所以最终路线是：**复用 v1.0.31 的四个 `.ko`，只去掉脚本层门槛。**

---

## 7. 下一步（待做）

1. 构建 `OPAirDrop-v1.0.31-RMX5010-test.zip`（`build_rmx_package.py`）。
2. 先创建 `/data/adb/opairshare/autostart-off`，装模块后重启 —— 只挂载系统文件、不自动换驱动，确认：
   - 能正常开机；
   - `MoseyApp` 被扫描安装（`pm path com.google.android.mosey`）；
   - 原厂 Wi-Fi 不受影响。
3. 手动 `control.sh start`，观察 `boot-start.log`、`kernel_matches`、`wonder0`、`mosey_server`、provider。
4. 若 OShare 接收不可用，改 `receive-session.sh` 的服务名 / 等桥接适配。
5. 全流程通过后，再考虑把改动并入 main 分支脚本（或提交 PR 给上游）。
