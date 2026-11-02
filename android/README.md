# CCB Android launcher

Native independent Android frontend to the same version-1 MOD registry as the
Godot desktop launcher. Minimum Android 8 (API 26). No game engine is embedded.

## Player workflow / 玩家流程

1. Open the launcher; the maintained/community catalog is fetched over HTTPS.
   Switch 简中 / EN and search names, IDs or authors. A failed refresh may display
   a clearly labeled cached catalog.
2. Download a CCB APK by release/ABI (or enter the exact tag required by a MOD).
   The system Download Manager handles the download. Tap Install APK and grant
   install permission; Android's package installer asks for confirmation.
3. Use the current game's public `Documents/cataclysm-ccb` data directory.
   Legacy private storage is **not supported**. Back up and migrate it in the
   game first; never uninstall the game to work around a signature conflict
   without backing up saves.
4. Grant file management permission when installing MODs. Android 11+ requires
   All files access for this direct public-directory implementation. No root,
   hidden APIs, private Android/data access or game-code changes are used.
5. Read version/Lua API/dependency/conflict/testing information. Close the game,
   confirm compatibility and install. Both catalog classes use the same installer.
6. Launch the game and enable the MOD when creating a world. Installation does
   not enable it in existing worlds and does not establish gameplay compatibility.
7. Updates and uninstall move previous files to `mod-backups`; saves are not
   touched. Recovery is manual: close the game and move the desired backup into
   `mods/<id>`. Unmanaged directories are never silently replaced.

安卓流程：浏览目录 → 下载并通过系统安装游戏 APK → 确认游戏使用公共目录 →
授权文件管理 → 阅读兼容信息并安装 MOD → 启动游戏、新建世界启用。
旧版私有数据须先备份迁移；卸载 MOD 不会删除存档，但依赖它的存档可能无法加载。

## Build and verify

Use Java 17, Android SDK 35 and the pinned Gradle wrapper:

```sh
./gradlew testDebugUnitTest lintDebug assembleDebug assembleDebugAndroidTest
./gradlew connectedDebugAndroidTest
```

Host tests cover path traversal, malformed archives, duplicate paths, incorrect
MOD identities, update preservation, backups, unmanaged directories and catalog
validation. Instrumentation tests exercise the current public catalog/package
on Android storage and the bilingual UI. They are not game-play tests.

The debug APK is **not a production release**. Release builds require persistent
signing credentials provided through `CCB_ANDROID_KEYSTORE`,
`CCB_ANDROID_STORE_PASSWORD`, `CCB_ANDROID_KEY_ALIAS`, `CCB_ANDROID_KEY_PASSWORD`.
Do not commit keystores or passwords. Keep the signing key backed up: changing
it prevents in-place upgrades. `./gradlew assembleRelease` builds the release.

Tag publication now requires both desktop exports and the signed Android build;
missing signing secrets fail the release rather than silently publishing only
desktop files. Configure the four repository Actions secrets
`CCB_ANDROID_KEYSTORE_BASE64`, `CCB_ANDROID_STORE_PASSWORD`,
`CCB_ANDROID_KEY_ALIAS`, `CCB_ANDROID_KEY_PASSWORD` before tagging. The first is
the base64-encoded dedicated launcher keystore, never the game's signing key.
Keep tag/versionCode/versionName changes synchronized for subsequent upgrades.

This is a GitHub-distributed application. Its file-management permission is
subject to separate Google Play policy review; Play Store approval is not claimed.

## Acceptance boundary

Do not mark the three-platform ecosystem complete from successful compilation.
Require Linux and Windows runtime installation tests, Android emulator tests,
signed artifacts, and a device smoke test of storage permission, APK installation,
MOD discovery in the real game, and world creation. MOD `validation.status` stays
as authored; a successful launcher installation must never rewrite it to passed.
