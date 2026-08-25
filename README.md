# AndroidStudio-Language-Packs

自动从 **IntelliJ IDEA Ultimate** 发行版中提取中 / 日 / 韩语言包，改写版本兼容信息后，封装成可安装进 **Android Studio** 的插件，并通过 GitHub Actions 定时发布到 Releases。

## 最新版本

<!-- LATEST-BEGIN -->
构建日期 **2026-08-25**，适配 **Android Studio 2026.1.3**（IntelliJ 平台 261），语言包提取自 **IDEA Ultimate 2026.1.5**（build 261.27258.48）。

| 版本 | 值 |
|---|---|
| Release | `v2026.1` |
| Android Studio | 2026.1.3 |
| IntelliJ 平台 | 261 |
| IDEA 来源 | 2026.1.5（build 261.27258.48） |
| 构建日期 | 2026-08-25 |

👉 [前往 Releases 下载最新语言包](https://github.com/byte-me-labs/AndroidStudio-Language-Packs/releases/latest)

## 产物

每次构建产出 3 个插件 zip：

| 文件 | 语言 |
|---|---|
| `localization-zh-<platform>.zip` | 简体中文 |
| `localization-ja-<platform>.zip` | 日本語 |
| `localization-ko-<platform>.zip` | 한국어 |

`<platform>` 为 IntelliJ 平台大版本号（如 AS 2026.1 → `261`）。

**安装**：`Settings → Plugins → ⚙️ → Install Plugin from Disk…` → 选择对应的 zip → 重启后到 `Settings → Appearance & Behavior → System Settings → Language and Region` 切换语言。

## 来源与许可

- 语言包提取自 **IntelliJ IDEA Ultimate**（JetBrains 商业软件，闭源）发行版内置的 `plugins/localization-*`。
- **注意**：Ultimate 是商业产品，其组件（含语言包）受 JetBrains 商业许可 / EULA 约束；本仓库不主张对语言包的再分发权利，仅作个人/社区使用目的提取重打包，使用风险自担。
- 翻译文本版权归 **JetBrains** 所有；本项目与 JetBrains / Google 无任何关联，不提供官方支持。

## License

本项目代码采用 [Apache License 2.0](LICENSE)。注意：**内置语言包内容**（翻译文本）的版权归 JetBrains 所有，且提取自商业版 Ultimate（JetBrains 未授权其组件再分发），不随本仓库的 Apache-2.0 授权。
