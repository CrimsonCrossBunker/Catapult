# Dabdoob — CCB 版

[![构建与导出](https://github.com/CrimsonCrossBunker/Catapult/actions/workflows/ci.yml/badge.svg)](https://github.com/CrimsonCrossBunker/Catapult/actions/workflows/ci.yml)

**Dabdoob** 是一个跨平台的《大灾变》游戏启动器与内容管理器，支持
[《大灾变：黑暗之日》](https://github.com/CleverRaven/Cataclysm-DDA)
及其衍生项目。本仓库在 Dabdoob 的基础上加入了对
[《大灾变：清水炸弹》（CCB）](https://github.com/CrimsonCrossBunker/Cataclysm-Cleanwater-Bomb)
的完整支持。

> **原作者与项目来源署名**
>
> 本仓库完整合并并保留了
> [`Hihahahalol/Catapult_Dabdoob`](https://github.com/Hihahahalol/Catapult_Dabdoob)
> 的项目内容和 Git 历史。**Dabdoob 由
> [Hihahahalol](https://github.com/Hihahahalol) 创建并持续开发**，其项目基于
> [qrrk 的 Catapult](https://github.com/qrrk/Catapult)。
>
> CCB 适配及本下游版本由
> [CrimsonCrossBunker](https://github.com/CrimsonCrossBunker) 维护。
> 本仓库不声称拥有上游项目的原始作者身份；原作者署名和 MIT 许可证均予以保留。

启动器内的“关于”页面同样列出了上述作者与项目来源。

## 下载

- [下载最新 CCB 版](https://github.com/CrimsonCrossBunker/Catapult/releases/latest)
- [查看全部 CCB 版发布](https://github.com/CrimsonCrossBunker/Catapult/releases)
- [查看 Dabdoob 原项目发布](https://github.com/Hihahahalol/Catapult_Dabdoob/releases)

请在 Release 页面下载与你的操作系统对应的文件。启动器为便携式程序，建议放入一个独立且可写的目录后运行。

## 支持的游戏

- 《大灾变：清水炸弹》（CCB，支持 Linux、Windows 和 macOS 实验版）
- 《大灾变：黑暗之日》（Cataclysm: Dark Days Ahead）
- Cataclysm: The Last Generation
- Cataclysm: Bright Nights
- Cataclysm: Era of Decay
- Cataclysm: There Is Still Hope

## 主要功能

- 自动下载、安装和更新游戏。
- 同时管理多个游戏版本，并可切换当前使用的版本。
- 更新游戏时保留用户数据。
- 管理模组、图块包、音效包和字体。
- 自动或手动备份存档。
- 支持从本仓库发布的版本自动更新启动器。
- 提供多语言、便携式界面和高分辨率缩放支持。

## 安装说明

### Windows

从 Release 页面下载 Windows 可执行文件，将其放入独立目录后直接运行。

### Linux

下载 Linux 可执行文件后添加执行权限：

```bash
chmod +x Dabdoob-CCB-linux.x86_64
```

根据发行版和所安装的游戏，可能还需要 SDL2、SDL2_image、SDL2_ttf、SDL2_mixer、FreeType 和 `zip`：

- Debian/Ubuntu：`sudo apt install libsdl2-image-2.0-0 libsdl2-ttf-2.0-0 libsdl2-mixer-2.0-0 libfreetype6 zip`
- Arch Linux：`sudo pacman -S sdl2 sdl2_image sdl2_ttf sdl2_mixer zip`
- Fedora：`sudo dnf install SDL2 SDL2_image SDL2_ttf SDL2_mixer freetype zip`

### macOS

macOS 包目前视为测试版本。如果 Gatekeeper 阻止运行未经公证的开发版本，请先确认文件来自本仓库的 Release 页面，再根据系统提示决定是否放行。

## 开发与持续集成

本项目使用 **Godot 3.6.1**。GitHub Actions 会自动完成以下工作：

- 检查 CCB 下载源、设置项、界面、署名和全部翻译是否完整。
- 导入 Godot 项目。
- 导出 Linux、Windows 和 macOS 构建。
- 上传每次构建的产物。
- 在推送版本标签时自动创建 GitHub Release。

一般贡献说明请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证与来源说明

本项目采用 MIT 许可证。原始版权声明保留在 [LICENSE](LICENSE) 中；下游来源与署名记录见 [NOTICE.md](NOTICE.md)。