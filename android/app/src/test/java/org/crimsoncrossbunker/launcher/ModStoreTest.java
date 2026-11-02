package org.crimsoncrossbunker.launcher;

import org.json.*;
import org.junit.*;
import org.junit.rules.TemporaryFolder;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.zip.*;
import static org.junit.Assert.*;

public class ModStoreTest {
    @Rule public TemporaryFolder folder = new TemporaryFolder();
    private JSONObject mod(String id, String version) throws Exception {
        return new JSONObject().put("id", id).put("version", version).put("download", "https://example.org/mod.zip")
            .put("type", "ccb-maintained").put("name", new JSONObject().put("en", "Test"))
            .put("ccb_versions", new JSONArray().put("test-build"));
    }
    private byte[] zip(String... entries) throws Exception {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(bytes)) {
            for (int i = 0; i < entries.length; i += 2) {
                zip.putNextEntry(new ZipEntry(entries[i]));
                zip.write(entries[i + 1].getBytes(StandardCharsets.UTF_8)); zip.closeEntry();
            }
        }
        return bytes.toByteArray();
    }
    @Test public void lifecyclePreservesSavesAndBackups() throws Exception {
        Path root = folder.newFolder().toPath(); ModStore store = new ModStore(root);
        Files.createDirectories(root.resolve("save/world")); Files.write(root.resolve("save/world/data"), new byte[]{42});
        store.install(mod("demo", "1"), zip("demo/main.lua", "return {}"));
        assertEquals("1", store.installed("demo").getString("version"));
        store.install(mod("demo", "2"), zip("demo/main.lua", "return {v=2}"));
        assertEquals("2", store.installed("demo").getString("version"));
        assertEquals(1, root.resolve("mod-backups").toFile().list().length);
        Path backup = store.uninstall("demo");
        assertTrue(Files.exists(backup.resolve("main.lua")));
        assertNull(store.installed("demo"));
        assertArrayEquals(new byte[]{42}, Files.readAllBytes(root.resolve("save/world/data")));
    }
    @Test public void corruptUpdateLeavesInstalledVersionUntouched() throws Exception {
        Path root = folder.newFolder().toPath(); ModStore store = new ModStore(root);
        store.install(mod("demo", "1"), zip("main.lua", "return {}"));
        assertThrows(IOException.class, () -> store.install(mod("demo", "2"), new byte[]{1, 2, 3}));
        assertEquals("1", store.installed("demo").getString("version"));
        assertEquals(0, root.resolve("mod-staging").toFile().list().length);
    }
    @Test public void traversalAndDuplicatePathsRejected() throws Exception {
        ModStore store = new ModStore(folder.newFolder().toPath());
        for (String name : new String[]{"../escape", "/absolute", "C:/escape", "demo/../../escape", "demo\\main.lua"}) {
            assertThrows(IOException.class, () -> store.install(mod("demo", "1"), zip(name, "bad")));
        }
        assertThrows(IOException.class, () -> store.install(mod("demo", "1"), zip("main.lua", "a", "MAIN.lua", "b")));
    }
    @Test public void wrongIdentityAndMultipleRootsRejected() throws Exception {
        ModStore store = new ModStore(folder.newFolder().toPath());
        assertThrows(IOException.class, () -> store.install(mod("demo", "1"), zip("modinfo.json", "[{\"type\":\"MOD_INFO\",\"id\":\"other\"}]")));
        assertThrows(IOException.class, () -> store.install(mod("demo", "1"), zip("one/main.lua", "a", "two/main.lua", "b")));
    }
    @Test public void legacyModInfoIsAccepted() throws Exception {
        ModStore store = new ModStore(folder.newFolder().toPath());
        store.install(mod("demo", "1"), zip("demo/modinfo.json", "{\"type\":\"MOD_INFO\",\"ident\":\"demo\"}"));
        assertNotNull(store.installed("demo"));
    }
    @Test public void unmanagedDirectoryIsNeverOverwritten() throws Exception {
        Path root = folder.newFolder().toPath(); ModStore store = new ModStore(root);
        Files.createDirectories(root.resolve("mods/demo"));
        assertThrows(IOException.class, () -> store.install(mod("demo", "1"), zip("main.lua", "a")));
        assertTrue(Files.exists(root.resolve("mods/demo")));
    }
    @Test public void catalogRejectsUnsafeEntriesAndSupportsBothTypes() throws Exception {
        JSONObject catalog = new JSONObject().put("schema_version", 1).put("mods", new JSONArray()
            .put(mod("official", "1")).put(mod("community", "1").put("type", "community")));
        assertEquals(2, ModStore.catalog(catalog.toString().getBytes(StandardCharsets.UTF_8)).size());
        catalog.getJSONArray("mods").getJSONObject(0).put("download", "http://example.org/mod.zip");
        assertThrows(IOException.class, () -> ModStore.catalog(catalog.toString().getBytes(StandardCharsets.UTF_8)));
        assertThrows(IOException.class, () -> ModStore.id("../demo"));
        assertThrows(IOException.class, () -> ModStore.id("CON"));
        assertThrows(IOException.class, () -> ModStore.https("https://user:pass@example.org/mod.zip"));
    }
    @Test public void truncatedArchiveDoesNotReplaceExistingMod() throws Exception {
        ModStore store = new ModStore(folder.newFolder().toPath());
        store.install(mod("demo", "1"), zip("main.lua", "old"));
        byte[] broken = zip("main.lua", "new content");
        byte[] truncated = java.util.Arrays.copyOf(broken, 40);
        assertThrows(IOException.class, () -> store.install(mod("demo", "2"), truncated));
        assertEquals("1", store.installed("demo").getString("version"));
    }
}
