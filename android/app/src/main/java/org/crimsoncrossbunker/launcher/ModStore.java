package org.crimsoncrossbunker.launcher;

import org.json.JSONArray;
import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.*;
import java.util.zip.*;

/** Filesystem/network contract shared by the Android UI and host-side tests. */
public final class ModStore {
    public static final String CATALOG = "https://crimsoncrossbunker.github.io/CCB-MOD/mods.json";
    public static final long MAX_PACKAGE = 128L * 1024 * 1024;
    public static final long MAX_EXPANDED = 512L * 1024 * 1024;
    private final Path root;

    public ModStore(Path root) throws IOException {
        this.root = root.toAbsolutePath().normalize();
        for (Path p = this.root; p != null; p = p.getParent()) {
            if (Files.isSymbolicLink(p)) throw new IOException("Symbolic link in storage path: " + p);
        }
        Files.createDirectories(this.root);
    }

    public static String id(String value) throws IOException {
        if (!value.matches("[A-Za-z0-9][A-Za-z0-9_-]{1,63}") ||
                value.matches("(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])"))
            throw new IOException("Invalid MOD ID: " + value);
        return value;
    }

    public static URL https(String value) throws IOException {
        URL url = new URL(value);
        if (!"https".equals(url.getProtocol()) || url.getHost().isEmpty() || url.getUserInfo() != null)
            throw new IOException("Only HTTPS URLs without credentials are supported");
        return url;
    }

    public static byte[] fetch(String address, long limit) throws IOException {
        URL url = https(address);
        for (int redirect = 0; redirect < 6; redirect++) {
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setConnectTimeout(15000);
            connection.setReadTimeout(30000);
            connection.setInstanceFollowRedirects(false);
            connection.setRequestProperty("User-Agent", "CCB-Launcher/1.3.0");
            try {
                int status = connection.getResponseCode();
                if (status >= 300 && status < 400) {
                    String location = connection.getHeaderField("Location");
                    if (location == null) throw new IOException("Redirect without Location");
                    url = https(new URL(url, location).toString());
                    continue;
                }
                if (status != 200) throw new IOException("HTTP " + status);
                if (connection.getContentLengthLong() > limit) throw new IOException("Download is too large");
                try (InputStream in = connection.getInputStream(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                    byte[] buffer = new byte[16384];
                    int count;
                    while ((count = in.read(buffer)) != -1) {
                        if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException();
                        if ((long) out.size() + count > limit) throw new IOException("Download is too large");
                        out.write(buffer, 0, count);
                    }
                    return out.toByteArray();
                }
            } finally { connection.disconnect(); }
        }
        throw new IOException("Too many redirects");
    }

    public static List<JSONObject> catalog(byte[] bytes) throws Exception {
        JSONObject data = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
        if (data.getInt("schema_version") != 1) throw new IOException("Unsupported catalog schema");
        JSONArray entries = data.getJSONArray("mods");
        List<JSONObject> mods = new ArrayList<>();
        Set<String> ids = new HashSet<>();
        if (entries.length() > 10000) throw new IOException("Catalog is too large");
        for (int i = 0; i < entries.length(); i++) {
            JSONObject mod = entries.getJSONObject(i);
            String key = id(mod.getString("id"));
            if (!ids.add(key.toLowerCase(Locale.ROOT))) throw new IOException("Duplicate MOD ID: " + key);
            https(mod.getString("download"));
            if (!Arrays.asList("community", "ccb-maintained").contains(mod.getString("type")))
                throw new IOException("Unknown maintenance type");
            if (mod.getString("version").isEmpty()) throw new IOException("Missing version");
            mod.getJSONObject("name");
            mod.getJSONArray("ccb_versions");
            mods.add(mod);
        }
        return mods;
    }

    private Path child(String directory) throws IOException {
        Path path = root.resolve(directory);
        if (Files.isSymbolicLink(path)) throw new IOException("Unsafe storage path: " + path);
        Files.createDirectories(path);
        return path;
    }

    public JSONObject installed(String modId) throws Exception {
        Path dir = child("mods").resolve(id(modId));
        if (Files.isSymbolicLink(dir)) throw new IOException("Unsafe MOD directory");
        Path marker = dir.resolve("catapult_mod.meta");
        if (!Files.exists(marker, LinkOption.NOFOLLOW_LINKS)) return null;
        if (Files.isSymbolicLink(marker) || Files.size(marker) > 1024 * 1024) throw new IOException("Unsafe MOD marker");
        return new JSONObject(new String(Files.readAllBytes(marker), StandardCharsets.UTF_8));
    }

    public synchronized void install(JSONObject mod, byte[] zip) throws Exception {
        String modId = id(mod.getString("id"));
        if (zip.length > MAX_PACKAGE) throw new IOException("Package is too large");
        Path target = child("mods").resolve(modId);
        if (Files.isSymbolicLink(target)) throw new IOException("Unsafe MOD directory");
        // Do not overwrite manually installed content without a launcher ownership marker.
        if (Files.exists(target) && installed(modId) == null)
            throw new IOException("Unmanaged MOD already exists; move it out of mods first: " + modId);
        Path stage = Files.createTempDirectory(child("mod-staging"), modId + "-");
        try {
            unpack(zip, stage);
            Path source = findMod(stage, modId);
            JSONObject marker = new JSONObject();
            marker.put("id", modId);
            marker.put("version", mod.getString("version"));
            marker.put("package_version", mod.getString("version"));
            marker.put("source_type", "ccb_registry");
            marker.put("download", mod.getString("download"));
            marker.put("modinfo", new JSONObject().put("id", modId).put("name", modId));
            Files.write(source.resolve("catapult_mod.meta"), marker.toString(2).getBytes(StandardCharsets.UTF_8));
            Path backup = child("mod-backups").resolve(modId + "-" + UUID.randomUUID());
            boolean old = Files.exists(target);
            if (old) Files.move(target, backup);
            try { Files.move(source, target); }
            catch (IOException failure) {
                if (old) {
                    try { Files.move(backup, target); }
                    catch (IOException restore) { failure.addSuppressed(restore); }
                }
                throw failure;
            }
        } finally { if (Files.exists(stage, LinkOption.NOFOLLOW_LINKS)) removeTree(stage); }
    }

    public synchronized Path uninstall(String modId) throws Exception {
        if (installed(modId) == null) throw new IOException("Not managed by this launcher");
        Path backup = child("mod-backups").resolve(id(modId) + "-" + UUID.randomUUID());
        Files.move(child("mods").resolve(modId), backup);
        return backup;
    }

    static void unpack(byte[] bytes, Path stage) throws IOException {
        long expanded = 0;
        int entries = 0;
        Set<String> names = new HashSet<>();
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(bytes))) {
            ZipEntry entry;
            byte[] buffer = new byte[16384];
            while ((entry = zip.getNextEntry()) != null) {
                if (++entries > 10000) throw new IOException("Too many ZIP entries");
                String name = entry.getName();
                if (name.startsWith("/") || name.contains("\\") || name.contains(":"))
                    throw new IOException("Unsafe ZIP path");
                for (String part : name.split("/")) {
                    if (part.equals("..") || part.equals(".") || part.endsWith(".") || part.endsWith(" "))
                        throw new IOException("Unsafe ZIP component");
                }
                if (!names.add(name.toLowerCase(Locale.ROOT))) throw new IOException("Duplicate ZIP path");
                Path output = stage.resolve(name).normalize();
                if (!output.startsWith(stage) || output.equals(stage)) throw new IOException("ZIP traversal");
                if (entry.isDirectory()) { Files.createDirectories(output); continue; }
                Files.createDirectories(output.getParent());
                try (OutputStream out = Files.newOutputStream(output, StandardOpenOption.CREATE_NEW)) {
                    int count;
                    while ((count = zip.read(buffer)) != -1) {
                        expanded += count;
                        if (expanded > MAX_EXPANDED) throw new IOException("Expanded ZIP is too large");
                        out.write(buffer, 0, count);
                    }
                }
            }
        }
        if (entries == 0) throw new IOException("Empty or invalid ZIP");
    }

    static Path findMod(Path stage, String modId) throws Exception {
        if (validMod(stage, modId)) return stage;
        List<Path> matches = new ArrayList<>();
        try (DirectoryStream<Path> dirs = Files.newDirectoryStream(stage)) {
            for (Path dir : dirs) if (Files.isDirectory(dir) && validMod(dir, modId)) matches.add(dir);
        }
        if (matches.size() != 1) throw new IOException("ZIP must contain exactly one matching MOD");
        return matches.get(0);
    }

    static boolean validMod(Path path, String modId) throws Exception {
        Path info = path.resolve("modinfo.json");
        if (!Files.exists(info)) return Files.isRegularFile(path.resolve("main.lua"));
        String text = new String(Files.readAllBytes(info), StandardCharsets.UTF_8).trim();
        JSONArray entries = text.startsWith("[") ? new JSONArray(text) : new JSONArray().put(new JSONObject(text));
        List<String> ids = new ArrayList<>();
        for (int i = 0; i < entries.length(); i++) {
            JSONObject item = entries.optJSONObject(i);
            if (item != null && item.optString("type").equals("MOD_INFO"))
                ids.add(item.optString("id", item.optString("ident")));
        }
        return ids.equals(Collections.singletonList(modId));
    }

    static void removeTree(Path root) throws IOException {
        // No FOLLOW_LINKS: never delete a symlink's target.
        Files.walkFileTree(root, new SimpleFileVisitor<Path>() {
            @Override public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                Files.delete(file); return FileVisitResult.CONTINUE;
            }
            @Override public FileVisitResult postVisitDirectory(Path dir, IOException error) throws IOException {
                if (error != null) throw error;
                Files.delete(dir); return FileVisitResult.CONTINUE;
            }
        });
    }
}
