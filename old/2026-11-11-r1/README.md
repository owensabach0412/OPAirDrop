# 旧版模块快照 r1（2026-11-11）

这是 **r2 之前**的模块状态（去门槛后的 OPAirDrop v1.0.31 for RMX5010）。

## 与 r2 的差异

| 文件 | r1 | r2 |
| --- | --- | --- |
| `bin/app-check.sh` | 要求 active split 数量 = 清单行数（6），并逐个比对全部哈希 | 只校验 `base.apk`（original / patched）与 `split_config.arm64_v8a.apk`，忽略语言/密度 split |

## 为什么要改

realme GT7 Pro 上手动安装的 Mosey 是 **13 个 split**：

- `base.apk`、`split_config.arm64_v8a.apk`、`en`、`es` 与模块清单**完全一致**；
- `xxhdpi` 哈希不同（`81f0ff4c…` vs 清单 `ff92800e…`）；
- 另有 `ar/et/fr/iw/ja/kk/ru/uk` 8 个语言 split，且没有 `zh`。

旧逻辑会因为 split 数量与 `xxhdpi` 哈希不同而报错，导致 provider 无法激活。r2 只校验真正影响代码与原生库的两个 split。

## 完整安装包

- r1：Release `rmx5010-v1.0.31` 资产 `OPAirDrop-v1.0.31-RMX5010-test.zip`
  SHA256 `1cdf3b55ceb0dd1c4674e830386f20dbf986e69ed7e3ecc96ecaea776647e50e`
- r2：Release `rmx5010-v1.0.31-r2` 资产 `OPAirDrop-v1.0.31-RMX5010-r2.zip`
  SHA256 `8b8147402b703e01fc452cc79718ce888d62334390b0e9fa52590d673cf4f5fd`

本目录只保存发生变化或关键的文本文件（`bin/app-check.sh`、`module.prop`、`SHA256SUMS`）；`payload/`、`webroot/`、`system/` 等二进制与 r1 发布包完全一致，不在仓库里重复存放。
