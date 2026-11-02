package org.crimsoncrossbunker.launcher;

import android.content.Context;
import android.content.Intent;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.*;
import org.json.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import java.nio.file.*;
import java.util.List;
import static org.junit.Assert.*;

/** Runs on an actual Android runtime, not the host JVM. No gameplay claim. */
@RunWith(AndroidJUnit4.class)
public class AndroidAcceptanceTest {
    @Test public void publishedCatalogPackageLifecycle() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        Path sandbox = Files.createTempDirectory(context.getExternalFilesDir(null).toPath(), "acceptance-");
        try {
            List<JSONObject> catalog = ModStore.catalog(ModStore.fetch(ModStore.CATALOG, 8 * 1024 * 1024));
            assertFalse("Live catalog must not be empty", catalog.isEmpty());
            JSONObject mod = catalog.get(0);
            byte[] zip = ModStore.fetch(mod.getString("download"), ModStore.MAX_PACKAGE);
            ModStore store = new ModStore(sandbox);
            store.install(mod, zip);
            assertEquals(mod.getString("version"), store.installed(mod.getString("id")).getString("version"));
            store.install(mod, zip);
            assertEquals(1, sandbox.resolve("mod-backups").toFile().list().length);
            try { store.install(mod, new byte[]{1, 2, 3}); fail("Corrupt package accepted"); }
            catch (java.io.IOException expected) { /* old installation must survive */ }
            assertNotNull(store.installed(mod.getString("id")));
            assertTrue(Files.exists(store.uninstall(mod.getString("id"))));
            assertNull(store.installed(mod.getString("id")));
        } finally { ModStore.removeTree(sandbox); }
    }

    @Test public void launcherLoadsLiveCatalogWithoutStoragePermission() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        context.getSharedPreferences("launcher", Context.MODE_PRIVATE).edit().putBoolean("zh", false).commit();
        UiDevice device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
        context.startActivity(new Intent(context, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        assertTrue(device.wait(Until.hasObject(By.text("CCB Launcher · Android")), 10000));
        assertTrue("Online catalog did not load", device.wait(Until.hasObject(By.textStartsWith("Catalog updated:")), 60000));
        assertNotNull(device.findObject(By.text("Storage access")));
        assertNotNull(device.findObject(By.text("Play")));
        device.takeScreenshot(new java.io.File(context.getExternalFilesDir(null), "launcher-en.png"));
        device.findObject(By.text("简中 / EN")).click();
        assertTrue(device.wait(Until.hasObject(By.text("存储授权")), 10000));
        assertTrue(device.wait(Until.hasObject(By.textStartsWith("目录已更新：")), 60000));
        device.takeScreenshot(new java.io.File(context.getExternalFilesDir(null), "launcher-zh.png"));
    }
}
