# 原始仓库备份（Upstream backup）

本目录保存 **Weverses/OPAirDrop 的原始内容**，与仓库根目录的 RMX5010 移植版分开存放。

- 上游仓库：<https://github.com/Weverses/OPAirDrop>
- 上游 Release：`v1.0.31`（tag `1031`），资产 `OPAirDrop-v1.0.31.zip`（20,741,717 B）
  SHA256：`cca0472e1a9b760aaf5f7795e0da3a0392275a5ec50d623f3fc530c15cd44980`
- 许可：GPL-3.0（见 `upstream-repo/LICENSE`）

## 内容

| 路径 | 说明 |
| --- | --- |
| `upstream-repo/` | 上游仓库 source tree 原样备份（`module/`、`kernel/`、`docs/`、`oshare/`、`native/`、`tools/`、`webui/` …） |
| `upstream-v1.0.31/` | 上游 v1.0.31 发布包中**被本移植修改过**的原始文件（`customize.sh`、`bin/control.sh`、`module.prop`、`README.md`） |

原始安装包另见 Release 资产 `UPSTREAM-OPAirDrop-v1.0.31-backup.zip`。

修改后的版本、去门槛补丁与真机测试记录见仓库根目录及 `rmx5010/`。
