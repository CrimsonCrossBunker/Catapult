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

The debug APK is **not a production release**. Release signing uses the same
three GPG-encrypted Actions Secrets as the CCB game repository:

| Secret | Value |
| --- | --- |
| `KEYSTORE` | ASCII-armored, GPG-encrypted original signing keystore |
| `KEYSTORE_PROPERTIES` | ASCII-armored, GPG-encrypted UTF-8 Java properties |
| `KEYSTORE_PASSWORD` | GPG decryption passphrase, not necessarily the keystore password |

Decrypted properties must contain `storePassword`, `keyAlias`, `keyPassword`.
The game's `storeFile` property is ignored: the launcher always uses the
decrypted `release.keystore` in its temporary signing directory. No password or
key is printed, committed or uploaded as an artifact. The workflow cleans the
directory on both success and failure. Gradle runs without a persistent daemon.

### Organization setup / 组织统一配置

1. In CrimsonCrossBunker's **Settings → Secrets and variables → Actions**, create
   the three organization Secrets above from the original backups. GitHub cannot
   reveal/copy the existing repository Secret values. Do not export them through
   Actions logs/artifacts or paste them into chat.
2. Set **Repository access → All repositories** if the intention is to grant all
   current/future organization repositories access. On the organization's current
   GitHub Free plan, organization Secrets cannot be used by private repositories;
   those require an eligible plan or separately configured repository Secrets.
3. Existing repository/environment Secrets with the same name override the
   organization value. Leave the game's working configuration intact until the
   shared configuration has been verified; then deliberately reconcile overrides
   so future rotation does not leave repositories on different keys.
4. Only workflows referencing these names actually use the signing material.
   Sharing Secrets does not automatically add signing to other repositories.
   The game already uses this contract; the launcher now does too.

组织共享步骤：使用原始备份创建上述三个组织 Secret，仓库访问范围选择全部仓库。
当前套餐仅支持公开仓库使用组织 Secret。原有同名仓库/环境 Secret 会优先于组织值，
不要在验证成功前删除主仓库的工作配置。已有值无法从 GitHub 读回。

Sharing the game key is an explicit organization policy: every authorized
repository's trusted workflow maintainers can potentially use that identity.
Protect write access, workflow changes and release tags. Never expose signing
Secrets to untrusted PR code. Keep offline backups of the original key and its
configuration; replacing the key breaks in-place Android upgrades. Sharing a key
does not merge the apps: their application IDs remain different.

Tag publication requires desktop exports, cross-platform acceptance and a signed
Android APK. Missing Secrets fail the release instead of publishing partial files.
For local signing, use an ephemeral directory in `CCB_ANDROID_SIGNING_DIR`, run
`.github/scripts/prepare_android_signing.sh` with the three inputs in a protected
environment, then `./gradlew --no-daemon assembleRelease`. Remove the temporary
signing files afterwards. Do not put secret values in shell history.
Keep tag/versionCode/versionName changes synchronized for subsequent upgrades.

This is a GitHub-distributed application. Its file-management permission is
subject to separate Google Play policy review; Play Store approval is not claimed.

## Acceptance boundary

Do not mark the three-platform ecosystem complete from successful compilation.
Require Linux and Windows runtime installation tests, Android emulator tests,
signed artifacts, and a device smoke test of storage permission, APK installation,
MOD discovery in the real game, and world creation. MOD `validation.status` stays
as authored; a successful launcher installation must never rewrite it to passed.
