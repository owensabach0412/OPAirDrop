# 上游文件备份（Original files backup）

本目录保存 **Weverses/OPAirDrop v1.0.31 发布包中、被 RMX5010 移植修改过的原始文件**，便于对照与回退。

- 上游仓库：<https://github.com/Weverses/OPAirDrop>
- 上游 Release：`v1.0.31`（tag `1031`），资产 `OPAirDrop-v1.0.31.zip`，20,741,717 B
  SHA256：`cca0472e1a9b760aaf5f7795e0da3a0392275a5ec50d623f3fc530c15cd44980`
- 许可：GPL-3.0（见上游仓库 `LICENSE`）

## 内容

| 文件 | 说明 |
| --- | --- |
| `upstream-v1.0.31/customize.sh` | 原始安装脚本（含 PJZ110 / SDK37 / 精确内核 / KernelSU 门槛） |
| `upstream-v1.0.31/bin/control.sh` | 原始运行脚本（含型号 preflight、原厂模块大小白名单、STOCK_NOTE 比对） |
| `upstream-v1.0.31/module.prop` | 原始模块属性 |
| `upstream-v1.0.31/README.md` | 原始说明 |

修改后的版本与完整 diff 见 `../rmx5010/`。

> 说明：这是一个 GitHub fork，完整原始代码树在 fork 的历史与上游仓库中都有；本目录只备份“被改动过的文件”，避免把 20 MB 二进制和整棵源码树重复塞进仓库。
