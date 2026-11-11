# 旧版模块快照 r2（2026-11-11）

r3 之前的模块状态。

## 与 r3 的差异

| 文件 | r2 | r3 |
| --- | --- | --- |
| `customize.sh` | `REPLACE=/system/system_ext/priv-app/MoseyApp`，自带 MoseyApp | 不再自带/替换 MoseyApp |
| `bin/callback.sh` | 固定 `SYSTEM_APK=/system_ext/priv-app/MoseyApp/base.apk` 并同时 patch 系统路径与 active 路径 | 只 patch `pm path` 得到的 active base |
| `bin/callback-bootstrap.sh` | 要求 GMS 模块表出现 `com.google.android.mosey`，否则 exit 6 | 增加 realme 证据（`NearbySharingService` + `qs_v1`），不再强拉 provider |
| `bin/grant-permissions.sh` | 任一权限 grant 失败即 `exit 3` | best-effort，未知权限跳过 |

## 为什么改

realme GT7 Pro 上：

- Mosey 由独立的 `com.google.android.mosey` KSU 模块提供（`/system/app`，app 进程可见），opairshare 自带的 `/system_ext/priv-app/MoseyApp` 对 app 进程不可见（会 `Failed to open APK` 崩溃）；
- GMS 不发布 `com.google.android.mosey` 模块行，只有 `NearbySharingService / qs_v1`；
- root 从后台 `am startservice` 拉 `ExternalSharingService` 被平台拒绝（`Unable to start service ... not found`）；
- SDK 36 没有 `android.permission.ACCESS_LOCAL_NETWORK`。

## 完整安装包

- r2：Release `rmx5010-v1.0.31-r2` 资产 `OPAirDrop-v1.0.31-RMX5010-r2.zip`
  SHA256 `8b8147402b703e01fc452cc79718ce888d62334390b0e9fa52590d673cf4f5fd`
- r3：Release `rmx5010-v1.0.31-r3` 资产 `OPAirDrop-v1.0.31-RMX5010-r3.zip`
  SHA256 `cdee18f6ab6833cb107e963e37cff4dc74cfd9b6dd3278d358e02fe4061fe425`

本目录只保存发生变化的脚本；`payload/`、`webroot/` 等二进制与 r2 发布包一致。
