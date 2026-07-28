# Dabdoob — CCB Edition

[![Build and export](https://github.com/CrimsonCrossBunker/Catapult/actions/workflows/ci.yml/badge.svg)](https://github.com/CrimsonCrossBunker/Catapult/actions/workflows/ci.yml)

**Dabdoob** is a cross-platform launcher and content manager for
[Cataclysm: Dark Days Ahead](https://github.com/CleverRaven/Cataclysm-DDA)
and its forks. This downstream edition adds first-class support for
[Cataclysm: Cleanwater Bomb (CCB)](https://github.com/CrimsonCrossBunker/Cataclysm-Cleanwater-Bomb).

> **Attribution / 署名：** This repository incorporates the complete
> [`Hihahahalol/Catapult_Dabdoob`](https://github.com/Hihahahalol/Catapult_Dabdoob)
> project and Git history. Dabdoob was created and developed by
> **[Hihahahalol](https://github.com/Hihahahalol)**, based on
> **[qrrk's Catapult](https://github.com/qrrk/Catapult)**. The CCB integration
> and this downstream edition are maintained by
> [CrimsonCrossBunker](https://github.com/CrimsonCrossBunker).
>
> 本仓库完整合并并保留了 Hihahahalol 的 Dabdoob 项目及 Git 历史；CCB
> 适配由 CrimsonCrossBunker 维护。原作者署名与 MIT 许可证均予以保留。

The launcher itself repeats this attribution on its **About** tab. Upstream
authorship is not claimed by CrimsonCrossBunker.

## Downloads

- [Latest CCB Edition release](https://github.com/CrimsonCrossBunker/Catapult/releases/latest)
- [All CCB Edition releases](https://github.com/CrimsonCrossBunker/Catapult/releases)
- [Original Dabdoob releases](https://github.com/Hihahahalol/Catapult_Dabdoob/releases)

## Supported games

- Cataclysm: Cleanwater Bomb (experimental releases on Linux, Windows, and macOS)
- Cataclysm: Dark Days Ahead
- Cataclysm: The Last Generation
- Cataclysm: Bright Nights
- Cataclysm: Era of Decay
- Cataclysm: There Is Still Hope

## Features

- Automatic game download, installation, and update.
- Multiple side-by-side installations with active-version switching.
- User-data preservation when updating games.
- Mod, tileset, soundpack, and font management.
- Automatic and manual saved-game backups.
- Self-update support for launcher releases published in this repository.
- Multilingual, portable interface with HiDPI scaling.

## Installation

The launcher is distributed as a self-contained executable. Download the
appropriate artifact from the
[latest release](https://github.com/CrimsonCrossBunker/Catapult/releases/latest),
place it in its own writable folder, and run it.

### Linux

- Give the launcher executable permission.
- The game may require SDL2, SDL2_image, SDL2_ttf, SDL2_mixer, FreeType, and
  `zip`, depending on your distribution.

Examples:

- Debian/Ubuntu: `sudo apt install libsdl2-image-2.0-0 libsdl2-ttf-2.0-0 libsdl2-mixer-2.0-0 libfreetype6 zip`
- Arch Linux: `sudo pacman -S sdl2 sdl2_image sdl2_ttf sdl2_mixer zip`
- Fedora: `sudo dnf install SDL2 SDL2_image SDL2_ttf SDL2_mixer freetype zip`

### macOS

The macOS package is currently considered beta. If Gatekeeper blocks an
unsigned development build, review the release notes before allowing it.

## Development and CI

The project targets **Godot 3.6.1**. GitHub Actions validates the CCB
integration, imports the project, and exports Linux, Windows, and macOS builds.
Every pull request and branch push receives build artifacts. A pushed version
tag also publishes the exported files as a GitHub release.

See [CONTRIBUTING.md](CONTRIBUTING.md) for general contribution guidance.

## License

MIT. The original copyright notices are retained in [LICENSE](LICENSE).
See [NOTICE.md](NOTICE.md) for the downstream provenance and attribution record.
