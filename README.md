# OPAirDrop for realme GT7 Pro (RMX5010) / kernel 6.6.89

本仓库是 [Weverses/OPAirDrop](https://github.com/Weverses/OPAirDrop) **v1.0.31 的 RMX5010 移植版**。

- **仓库根目录 = 可直接安装的模块内容**（去掉了 PJZ110 / SDK37 / 精确 6.6.118 内核 / 原厂模块大小 / 原厂 build-id 等门槛）。
- **`backup/` = 原始仓库**（上游 source tree 原样备份）与 v1.0.31 发布包中被修改的原始文件。
- **`rmx5010/` = 移植记录**：设备信息、静态 ABI 对照、真机测试日志、去门槛补丁与测试脚本。

> 发布包（可直接刷入）：[Releases · rmx5010-v1.0.31](https://github.com/owensabach0412/OPAirDrop/releases/tag/rmx5010-v1.0.31)
> 其中 `OPAirDrop-v1.0.31-RMX5010-test.zip` 为移植包，`UPSTREAM-OPAirDrop-v1.0.31-backup.zip` 为上游原包备份。

---

## 目标设备

| 项目 | 值 |
| --- | --- |
| 机型 | realme GT7 Pro（RMX5010，CN） |
| 系统 | `RMX5010_16.0.5.700(CN01)`，Android 16，SDK 36 |
| 平台 | `sun` / SM8750 |
| 内核 | `6.6.89-android15-8-g7e1f3c083cc6-abogki467167594-4k`（4 KB 页） |
| WLAN | `qca_cld3_peach_v2`，qcacld `5.2.1.119O`，固件 build `10097fff` |
| Root | KernelSU + LSPosed |

## 验证状态

**内核驱动链路：已在真机验证通过。**

- 静态 ABI：v1.0.31 四个 `.ko` 的 1,013 条导入符号中，被 RMX5010 `abi_gki_aarch64.stg` 覆盖的 729 条 **CRC 全部一致、0 冲突**；`module_layout = 0x4e276f37` 双方相同。
- 同名 dry-run：`insmod mac80211.ko` / `qca_cld3_peach_v2.ko` 返回 `File exists`（vermagic + 全量 CRC 通过）。
- 真实换入：`provider → qca（带 passthru 参数）→ mac80211 → wonder` 全部 `rc=0`；固件 `10097fff`；`OP13NAN: nan_data=1`；98 个 AWDL 参数；Wi-Fi 正常；回滚原厂成功。
- 唯一注意点：**必须先装 `oneplus13_wonder_provider.ko` 再装 qca**，否则 `Unknown symbol cnss_set_vendor_wonder_priv_data`（realme 原厂 CNSS 不导出该符号）。

**用户态：栈已起来，AirDrop 实收待验证。**

r3 起 Mosey 使用设备现有来源（独立的 `com.google.android.mosey` KernelSU 模块放在 `/system/app`，或用户安装），本模块不再自带 `/system_ext/priv-app/MoseyApp`，只对 `pm path` 得到的 active base 做 bind mount 补丁。

真机启动链（重启后自动）：

```
DRIVER_SWAP_DONE -> NATIVE_BINDER_READY -> PATCH_AUTH_READY -> COEX_READY
-> RECEIVE_WARMUP_BEGIN -> PROVIDER_START_DONE
control.sh status: stack=stage44_coexist_owned, Binder service found, Wi-Fi connected
```

仍需验证：打开 Quick Share / OShare 分享面板后，Mac/iPhone 能否发现并完成收发（provider 由 GMS/分享界面拉起，模块不再从后台强拉）。

## 安装

```sh
adb push OPAirDrop-v1.0.31-RMX5010-test.zip /data/local/tmp/
adb shell su -c "ksud module install /data/local/tmp/OPAirDrop-v1.0.31-RMX5010-test.zip"
# 重启生效
```

建议先分阶段验证：`touch /data/adb/opairshare/autostart-off` 后再安装并重启（只挂载系统文件、不自动换驱动），确认开机与 Mosey 安装正常后，再手动 `control.sh start`。

回滚：

```sh
adb shell su -c "ksud module disable opairshare"   # 或 uninstall
adb reboot
```

## 目录

```
.                     RMX5010 模块（customize.sh / bin / system / payload / webroot …）
├── backup/
│   ├── upstream-repo/        上游仓库 source 原样备份
│   └── upstream-v1.0.31/     被修改过的上游 v1.0.31 发布文件
├── rmx5010/
│   ├── README.md             移植说明
│   ├── analysis.md           调查与测试记录
│   ├── build_rmx_package.py  去门槛打包脚本
│   ├── patches/de-gate.patch 完整 diff
│   ├── scripts/              取证 / dry-run / 驱动换入脚本
│   └── logs/                 脱敏真机日志
└── SHA256SUMS                模块文件校验（已按本仓库内容重新生成）
```

> 说明：仓库根目录的 `README.md`、`module.prop` 描述与 `SHA256SUMS` 相对上游发布包有更新；字节级一致的原始安装包仍是 Release 中的 zip。

## 许可

上游项目 GPL-3.0；`LICENSES/`、`THIRD_PARTY_NOTICES.md` 与上游保持一致。本项目与 Google、Apple、Oplus（OPPO / OnePlus / realme）无隶属或合作关系。
