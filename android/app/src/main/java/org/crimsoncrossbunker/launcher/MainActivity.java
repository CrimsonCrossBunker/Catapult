package org.crimsoncrossbunker.launcher;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.text.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** A native Android frontend to the same registry used by the desktop launcher. */
public final class MainActivity extends Activity {
    private static final java.util.concurrent.atomic.AtomicBoolean ACTIVE = new java.util.concurrent.atomic.AtomicBoolean();
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final List<JSONObject> catalog = new ArrayList<>();
    private LinearLayout list;
    private TextView status;
    private EditText search;
    private boolean busy;
    private boolean zh;
    private String category = "all";
    private static final String RELEASES = "https://api.github.com/repos/CrimsonCrossBunker/Cataclysm-Cleanwater-Bomb/releases?per_page=30";
    private static final String[] GAMES = {"com.crimsoncrossbunker.cataclysmcb", "com.crimsoncrossbunker.cataclysmcb.experimental", "com.crimsoncrossbunker.cataclysmcb.newui"};

    private String t(String cn, String en) { return zh ? cn : en; }
    private android.content.SharedPreferences prefs() { return getSharedPreferences("launcher", MODE_PRIVATE); }
    private Path gameRoot() {
        return Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS).toPath().resolve("cataclysm-ccb");
    }
    private ModStore store() throws Exception { return new ModStore(gameRoot()); }
    private boolean storageReady() {
        return Build.VERSION.SDK_INT >= 30 ? Environment.isExternalStorageManager() :
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
    }

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        zh = prefs().getBoolean("zh", Locale.getDefault().getLanguage().equals("zh"));
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(20, 20, 20, 8);
        root.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(20 + insets.getSystemWindowInsetLeft(), 12 + insets.getSystemWindowInsetTop(),
                20 + insets.getSystemWindowInsetRight(), 8 + insets.getSystemWindowInsetBottom());
            return insets;
        });
        setContentView(root);
        TextView title = new TextView(this);
        title.setText("CCB Launcher · Android"); title.setTextSize(24); root.addView(title);
        LinearLayout top = row(root);
        button(top, t("刷新目录", "Refresh"), this::refresh);
        button(top, "简中 / EN", () -> { prefs().edit().putBoolean("zh", !zh).apply(); recreate(); });
        button(top, t("MOD 网站", "MOD website"), () -> open("https://crimsoncrossbunker.github.io/CCB-MOD/"));
        LinearLayout games = row(root);
        button(games, t("下载游戏", "Get game"), this::releases);
        button(games, t("安装 APK", "Install APK"), this::installApk);
        button(games, t("启动游戏", "Play"), this::launchGame);
        LinearLayout versions = row(root);
        button(versions, t("按版本标签查找 APK", "Find APK by release tag"), () -> {
            EditText tag = new EditText(this); tag.setSingleLine(true);
            tag.setHint("2026-09-07-2111");
            new AlertDialog.Builder(this).setTitle(t("输入 MOD 要求的游戏版本", "Enter the game release required by your MOD"))
                .setView(tag).setPositiveButton(t("查找", "Find"), (d, w) -> {
                    String value = tag.getText().toString().trim();
                    if (!value.isEmpty()) releases("https://api.github.com/repos/CrimsonCrossBunker/Cataclysm-Cleanwater-Bomb/releases/tags/" + Uri.encode(value));
                }).setNegativeButton(t("取消", "Cancel"), null).show();
        });
        LinearLayout tools = row(root);
        button(tools, t("存储授权", "Storage access"), this::requestStorage);
        button(tools, t("数据说明", "Data help"), () -> message(t("数据与备份", "Data and backups"),
            gameRoot() + "\n\n" + t("仅支持当前 CCB 公共数据目录。旧版或开启「Use Legacy Storage」的游戏，请先在游戏内关闭该选项并备份、迁移数据；启动器不会读取 Android/data 私有目录。更新或卸载的 MOD 保存在 mod-backups，不会删除存档。恢复时关闭游戏，把对应备份移回 mods。安装 MOD 后仍需在游戏创建世界时启用。", "Only the current CCB public data directory is supported. Disable Use Legacy Storage in the game and back up/migrate old data first. Android/data is not accessed. Updated/uninstalled MODs are kept in mod-backups; saves are never deleted. To restore, close the game and move a backup back into mods. Enable installed MODs when creating a world.")));
        LinearLayout filters = row(root);
        button(filters, t("全部", "All"), () -> { category = "all"; render(); });
        button(filters, t("官方维护", "Maintained"), () -> { category = "ccb-maintained"; render(); });
        button(filters, t("民间", "Community"), () -> { category = "community"; render(); });
        search = new EditText(this);
        search.setSingleLine(true); search.setHint(t("搜索名称、ID、作者", "Search name, ID, author")); root.addView(search);
        search.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            public void onTextChanged(CharSequence s, int start, int before, int count) { render(); }
            public void afterTextChanged(Editable text) {}
        });
        status = new TextView(this); root.addView(status);
        ScrollView scroll = new ScrollView(this);
        root.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
        list = new LinearLayout(this); list.setOrientation(LinearLayout.VERTICAL); scroll.addView(list);
        refresh();
    }

    private LinearLayout row(LinearLayout parent) {
        LinearLayout row = new LinearLayout(this); parent.addView(row); return row;
    }
    private void button(LinearLayout parent, String title, Runnable action) {
        Button button = new Button(this); button.setText(title); button.setAllCaps(false);
        parent.addView(button, new LinearLayout.LayoutParams(0, -2, 1));
        button.setOnClickListener(v -> { if (!busy) action.run(); });
    }
    private void message(String title, String body) {
        if (!isFinishing() && !isDestroyed()) new AlertDialog.Builder(this).setTitle(title).setMessage(body).setPositiveButton("OK", null).show();
    }
    private void error(Exception ex) { message(t("操作失败", "Operation failed"), ex.toString()); }
    private void open(String url) {
        try { ModStore.https(url); startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); }
        catch (Exception e) { error(e); }
    }
    private interface Task { String run() throws Exception; }
    private void task(String label, Task task) {
        if (busy || !ACTIVE.compareAndSet(false, true)) {
            status.setText(t("上一项操作仍在完成，请稍后刷新。", "The previous operation is still finishing; refresh shortly."));
            return;
        }
        busy = true; status.setText(label);
        worker.execute(() -> {
            String result = null; Exception failure = null;
            try { result = task.run(); } catch (Exception ex) { failure = ex; }
            finally { ACTIVE.set(false); }
            final String outcome = result; final Exception problem = failure;
            runOnUiThread(() -> {
                busy = false;
                if (isFinishing() || isDestroyed()) return;
                status.setText(problem == null ? outcome : t("失败；未标记为成功。", "Failed; not marked as successful."));
                if (problem != null) error(problem);
                render();
            });
        });
    }

    private void refresh() {
        task(t("正在拉取目录…", "Fetching catalog…"), () -> {
            Path cache = getFilesDir().toPath().resolve("catalog.json");
            List<JSONObject> entries;
            boolean offline = false;
            try {
                byte[] bytes = ModStore.fetch(ModStore.CATALOG, 8 * 1024 * 1024);
                entries = ModStore.catalog(bytes);
                Path temp = cache.resolveSibling("catalog.tmp"); Files.write(temp, bytes);
                Files.move(temp, cache, StandardCopyOption.REPLACE_EXISTING);
            } catch (Exception network) {
                if (!Files.exists(cache)) throw network;
                entries = ModStore.catalog(Files.readAllBytes(cache)); offline = true;
            }
            synchronized (catalog) { catalog.clear(); catalog.addAll(entries); }
            return (offline ? t("离线缓存（可能过时）：", "Offline cache (may be stale): ") : t("目录已更新：", "Catalog updated: ")) + entries.size();
        });
    }

    private String local(JSONObject entry, String field) {
        JSONObject text = entry.optJSONObject(field);
        if (text == null) return entry.optString(field, "");
        return text.optString(zh ? "zh-Hans" : "en", text.optString(zh ? "en" : "zh-Hans", ""));
    }
    private void render() {
        if (list == null) return;
        list.removeAllViews();
        String query = search.getText().toString().toLowerCase(Locale.ROOT);
        List<JSONObject> snapshot;
        synchronized (catalog) { snapshot = new ArrayList<>(catalog); }
        int count = 0;
        for (JSONObject mod : snapshot) {
            if (!category.equals("all") && !category.equals(mod.optString("type"))) continue;
            if (!mod.toString().toLowerCase(Locale.ROOT).contains(query)) continue;
            count++;
            Button entry = new Button(this);
            entry.setAllCaps(false); entry.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
            String installed = "";
            if (storageReady()) try {
                JSONObject marker = store().installed(mod.getString("id"));
                if (marker != null) installed = " · " + t("已安装 ", "Installed ") + marker.optString("version");
            } catch (Exception ex) { installed = " · " + t("本地状态异常", "Local state error"); }
            entry.setText(local(mod, "name") + " · " + mod.optString("version") + installed + "\n" + mod.optString("id"));
            entry.setOnClickListener(v -> { if (!busy) details(mod); }); list.addView(entry);
        }
        if (count == 0) { TextView empty = new TextView(this); empty.setText(t("没有匹配的 MOD。", "No matching MODs.")); list.addView(empty); }
    }

    private void details(JSONObject mod) {
        String[] keys = {"id", "type", "version", "authors", "maintainers", "ccb_adapters", "updated_at", "ccb_versions", "lua_api", "dependencies", "conflicts", "license", "validation"};
        String[] cn = {"ID", "维护类型", "版本", "作者", "维护人", "适配人", "更新时间", "适配游戏版本", "Lua API", "依赖", "冲突", "许可证", "实测状态"};
        StringBuilder body = new StringBuilder(local(mod, "description")).append("\n\n");
        for (int i = 0; i < keys.length; i++) body.append(zh ? cn[i] : keys[i]).append(": ").append(detailValue(mod, keys[i])).append('\n');
        body.append('\n').append(local(mod, "play_notes"));
        body.append("\n\n").append(t("Lua MOD 会在游戏进程内运行，只安装你信任的作者。兼容性由作者声明，不等于实测通过。更新/卸载前请关闭游戏并备份存档。", "Lua MODs execute in the game process. Only install authors you trust. Declared compatibility is not proof of testing. Close the game and back up saves before updates/removal."));
        new AlertDialog.Builder(this).setTitle(local(mod, "name")).setMessage(body.toString())
            .setPositiveButton(t("安装 / 更新", "Install / update"), (d, w) -> confirmInstall(mod))
            .setNeutralButton(t("卸载", "Uninstall"), (d, w) -> uninstall(mod))
            .setNegativeButton(t("关闭", "Close"), null).show();
    }

    private String detailValue(JSONObject mod, String key) {
        Object value = mod.opt(key);
        if (value == null || value == JSONObject.NULL) return t("未声明", "Not declared");
        if (key.equals("type")) return mod.optString(key).equals("community") ? t("民间作者维护", "Community maintained") : t("CCB 收录维护", "CCB maintained");
        if (key.equals("validation")) {
            JSONObject validation = mod.optJSONObject(key);
            String state = validation == null ? "not-tested" : validation.optString("status", "not-tested");
            String label = state.equals("passed") ? t("声明已通过", "Reported passed") : state.equals("failed") ? t("测试失败", "Failed") : t("未实测", "Not tested");
            return label + (validation == null ? "" : " / " + validation.optString("ccb_version", "—") + " / " + validation.optString("checked_at", "—"));
        }
        if (value instanceof JSONArray) {
            JSONArray array = (JSONArray) value;
            List<String> parts = new ArrayList<>();
            for (int i = 0; i < array.length(); i++) parts.add(array.optString(i));
            return parts.isEmpty() ? t("无", "None") : android.text.TextUtils.join(", ", parts);
        }
        return value.toString();
    }

    private void confirmInstall(JSONObject mod) {
        if (!storageReady()) { requestStorage(); return; }
        new AlertDialog.Builder(this).setTitle(t("确认兼容性与数据目录", "Confirm compatibility and storage"))
            .setMessage(t("请确认：游戏已关闭，已使用公共数据目录，所装游戏版本在下列兼容列表中，已检查依赖和冲突。未实测 MOD 请使用测试存档。\n", "Confirm the game is closed, public storage is enabled, the installed game is in this compatibility list, and dependencies/conflicts have been checked. Use a test save for untested MODs.\n") + mod.optJSONArray("ccb_versions") + "\n" + gameRoot())
            .setPositiveButton(t("确认安装", "Confirm install"), (d, w) -> task(t("下载并安装中，请勿退出…", "Downloading/installing; keep app open…"), () -> {
                Path zip = Files.createTempFile(getCacheDir().toPath(), "mod-", ".zip");
                try {
                    try (java.io.OutputStream out = Files.newOutputStream(zip)) {
                        ModStore.download(mod.getString("download"), out, ModStore.MAX_PACKAGE);
                    }
                    store().install(mod, zip);
                } finally { Files.deleteIfExists(zip); }
                return t("安装完成。在游戏创建世界时启用 MOD。", "Installed. Enable the MOD when creating a world.");
            })).setNegativeButton(t("取消", "Cancel"), null).show();
    }

    private void uninstall(JSONObject mod) {
        if (!storageReady()) { requestStorage(); return; }
        new AlertDialog.Builder(this).setTitle(t("卸载 MOD？", "Uninstall MOD?"))
            .setMessage(t("请先关闭游戏。依赖它的存档可能无法继续加载。MOD 将移入 mod-backups，可手动恢复；存档不受改动。", "Close the game first. Saves depending on this MOD may stop loading. The MOD is moved to mod-backups for manual recovery; saves are not modified."))
            .setPositiveButton(t("卸载", "Uninstall"), (d, w) -> task(t("正在卸载…", "Uninstalling…"), () -> store().uninstall(mod.getString("id")).toString()))
            .setNegativeButton(t("取消", "Cancel"), null).show();
    }

    private void requestStorage() {
        if (storageReady()) { message(t("已授权", "Access granted"), gameRoot().toString()); return; }
        new AlertDialog.Builder(this).setTitle(t("允许管理游戏 MOD 文件", "Allow game MOD file management"))
            .setMessage(t("需要访问 Documents/cataclysm-ccb，才能让游戏读取已安装 MOD。Android 11+ 会显示「所有文件访问」授权；启动器只管理该目录中的 mods、mod-staging、mod-backups。拒绝授权仍可浏览目录、下载游戏。", "Access to Documents/cataclysm-ccb is needed for the game to read MODs. Android 11+ shows an All files access permission; this launcher only manages mods, mod-staging and mod-backups there. You can browse the catalog and download the game without granting it."))
            .setPositiveButton(t("前往授权", "Grant access"), (d, w) -> {
                if (Build.VERSION.SDK_INT >= 30) {
                    try { startActivity(new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:" + getPackageName()))); }
                    catch (ActivityNotFoundException e) { startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)); }
                } else requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, 10);
            }).setNegativeButton(t("取消", "Cancel"), null).show();
    }

    private void releases() {
        releases(RELEASES);
    }

    private void releases(String address) {
        task(t("获取游戏版本…", "Fetching releases…"), () -> {
            String json = new String(ModStore.fetch(address, 12 * 1024 * 1024), StandardCharsets.UTF_8);
            JSONArray releases = address.equals(RELEASES) ? new JSONArray(json) : new JSONArray().put(new JSONObject(json));
            List<String> names = new ArrayList<>(); List<JSONObject> assets = new ArrayList<>();
            for (int i = 0; i < releases.length(); i++) {
                JSONObject release = releases.getJSONObject(i); JSONArray files = release.getJSONArray("assets");
                for (int j = 0; j < files.length(); j++) {
                    JSONObject asset = files.getJSONObject(j);
                    if (asset.getString("name").toLowerCase(Locale.ROOT).endsWith(".apk")) {
                        names.add(release.getString("tag_name") + " / " + asset.getString("name")); assets.add(asset);
                    }
                }
            }
            if (assets.isEmpty()) throw new IllegalStateException(t("所查版本没有 APK。请确认版本标签或选择其他版本。", "No APK assets in this release. Check the tag or select another release."));
            runOnUiThread(() -> {
                if (isFinishing() || isDestroyed()) return;
                new AlertDialog.Builder(this).setTitle(t("选择版本和架构（最近 30 个版本）", "Choose release and ABI (latest 30 releases)"))
                    .setItems(names.toArray(new String[0]), (d, which) -> downloadApk(assets.get(which)))
                    .setNegativeButton(t("关闭", "Close"), null).show();
            });
            return t("手机架构：", "Device ABIs: ") + Arrays.toString(Build.SUPPORTED_ABIS);
        });
    }

    private void downloadApk(JSONObject asset) {
        try {
            String url = asset.getString("browser_download_url"); ModStore.https(url);
            String name = "ccb-" + UUID.randomUUID() + ".apk";
            DownloadManager manager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
            long previous = prefs().getLong("apkDownload", -1);
            if (previous != -1) {
                try (Cursor cursor = manager.query(new DownloadManager.Query().setFilterById(previous))) {
                    if (cursor.moveToFirst()) {
                        int state = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
                        if (state == DownloadManager.STATUS_RUNNING || state == DownloadManager.STATUS_PENDING || state == DownloadManager.STATUS_PAUSED) {
                            message(t("下载进行中", "Download in progress"), t("请等待当前 APK 下载完成，或在系统下载管理中取消它。", "Wait for the current APK, or cancel it in the system download manager.")); return;
                        }
                    }
                }
            }
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url))
                .setTitle(asset.getString("name"))
                .setMimeType("application/vnd.android.package-archive")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, name);
            long download = manager.enqueue(request);
            prefs().edit().putLong("apkDownload", download).apply();
            message(t("已开始下载", "Download started"), t("可在系统通知查看进度。下载完成后点击「安装 APK」，由系统确认安装；签名不匹配时不要卸载旧游戏，先备份存档。", "Track progress in system notifications. When complete, tap Install APK for system confirmation. If signatures conflict, back up saves before considering removal of an old game."));
        } catch (Exception ex) { error(ex); }
    }

    private void installApk() {
        try {
            if (!getPackageManager().canRequestPackageInstalls()) {
                startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + getPackageName())));
                return;
            }
            DownloadManager manager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
            long download = prefs().getLong("apkDownload", -1);
            try (Cursor cursor = manager.query(new DownloadManager.Query().setFilterById(download))) {
                if (!cursor.moveToFirst()) throw new IllegalStateException(t("请先下载游戏 APK", "Download a game APK first"));
                int state = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
                if (state != DownloadManager.STATUS_SUCCESSFUL) throw new IllegalStateException(t("APK 未下载完成，状态：", "APK not complete, status: ") + state);
            }
            Uri uri = manager.getUriForDownloadedFile(download);
            if (uri == null) throw new IllegalStateException("Downloaded APK is missing");
            startActivity(new Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION));
        } catch (Exception ex) { error(ex); }
    }

    private void launchGame() {
        List<String> names = new ArrayList<>(); List<Intent> intents = new ArrayList<>();
        for (String name : GAMES) {
            Intent intent = getPackageManager().getLaunchIntentForPackage(name);
            if (intent != null) {
                String label = name.endsWith(".experimental") ? t("实验版", "Experimental") : name.endsWith(".newui") ? t("新界面版", "New UI") : t("标准版", "Standard");
                try { label += " · " + getPackageManager().getPackageInfo(name, 0).versionName; }
                catch (PackageManager.NameNotFoundException ignored) { }
                names.add(label); intents.add(intent);
            }
        }
        if (intents.isEmpty()) message(t("未安装游戏", "Game not installed"), t("请先下载并安装 CCB APK。", "Download and install a CCB APK first."));
        else if (intents.size() == 1) startActivity(intents.get(0));
        else new AlertDialog.Builder(this).setTitle(t("选择游戏", "Choose game"))
            .setItems(names.toArray(new String[0]), (d, i) -> startActivity(intents.get(i))).show();
    }

    @Override protected void onResume() { super.onResume(); if (list != null) render(); }
    @Override protected void onDestroy() {
        // Let an in-progress filesystem transaction finish even on rotation.
        worker.shutdown(); super.onDestroy();
    }
}
