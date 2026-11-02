"""Exercise the shared GPG contract without any production signing credentials."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / '.github/scripts/prepare_android_signing.sh'


class SharedSigningTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ccb-signing-test-')
        self.root = Path(self.temp.name)
        self.gpg_home = self.root / 'gnupg'
        self.gpg_home.mkdir(mode=0o700)
        self.destination = self.root / 'decrypted'
        self.destination.mkdir()
        self.env = dict(os.environ, GNUPGHOME=str(self.gpg_home),
                        CCB_ANDROID_SIGNING_DIR=str(self.destination),
                        KEYSTORE_PASSWORD='disposable-fixture-passphrase')
        self.key = b'disposable fixture, not a real signing key'
        self.properties = b'storeFile=release.keystore\nstorePassword=test-only\nkeyAlias=test\nkeyPassword=test-only\n'
        self.env['KEYSTORE'] = self.encrypt(self.key)
        self.env['KEYSTORE_PROPERTIES'] = self.encrypt(self.properties)

    def tearDown(self):
        subprocess.run(['gpgconf', '--kill', 'gpg-agent'], env=self.env, capture_output=True)
        self.temp.cleanup()

    def encrypt(self, value):
        return subprocess.run(['gpg', '--batch', '--yes', '--pinentry-mode', 'loopback',
                               '--passphrase', self.env['KEYSTORE_PASSWORD'], '--armor',
                               '--symmetric', '--cipher-algo', 'AES256'], input=value,
                              env=self.env, capture_output=True, check=True).stdout.decode()

    def prepare(self):
        return subprocess.run(['bash', str(SCRIPT)], env=self.env, capture_output=True, text=True)

    def test_round_trip_and_private_permissions(self):
        result = self.prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.destination / 'release.keystore').read_bytes(), self.key)
        self.assertEqual((self.destination / 'keystore.properties').read_bytes(), self.properties)
        for path in self.destination.iterdir():
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_missing_secret_fails_before_writing(self):
        del self.env['KEYSTORE_PROPERTIES']
        self.assertNotEqual(self.prepare().returncode, 0)
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_wrong_passphrase_does_not_leak_inputs(self):
        self.env['KEYSTORE_PASSWORD'] = 'incorrect-fixture-password'
        result = self.prepare()
        self.assertNotEqual(result.returncode, 0)
        output = result.stdout + result.stderr
        for name in ('KEYSTORE', 'KEYSTORE_PROPERTIES', 'KEYSTORE_PASSWORD'):
            self.assertNotIn(self.env[name], output)

    def test_existing_file_is_not_overwritten(self):
        target = self.destination / 'release.keystore'
        target.write_bytes(b'preserve-existing')
        self.assertNotEqual(self.prepare().returncode, 0)
        self.assertEqual(target.read_bytes(), b'preserve-existing')

    @unittest.skipUnless(os.environ.get('CCB_TEST_SIGNING_BUILD') == '1',
                         'Opt-in: requires Android SDK and builds a disposable-key APK')
    def test_disposable_key_signs_release_apk(self):
        original = self.root / 'fixture.jks'
        subprocess.run(['keytool', '-genkeypair', '-keystore', str(original),
                        '-storetype', 'JKS', '-storepass', 'fixture-only-password',
                        '-keypass', 'fixture-only-password', '-alias', 'fixture',
                        '-dname', 'CN=Disposable CCB CI fixture', '-keyalg', 'RSA',
                        '-keysize', '2048', '-validity', '1'],
                       env=self.env, capture_output=True, check=True)
        self.env['KEYSTORE'] = self.encrypt(original.read_bytes())
        # Prove a game-specific path is not used by the launcher.
        self.env['KEYSTORE_PROPERTIES'] = self.encrypt(
            b'storeFile=game-specific/ignored.keystore\nstorePassword=fixture-only-password\n'
            b'keyAlias=fixture\nkeyPassword=fixture-only-password\n')
        self.assertEqual(self.prepare().returncode, 0)
        android = SCRIPT.parents[2] / 'android'
        result = subprocess.run(['./gradlew', '--no-daemon', ':app:assembleRelease'],
                                cwd=android, env=self.env, capture_output=True, text=True,
                                timeout=240)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        apksigner = Path(self.env['ANDROID_HOME']) / 'build-tools/34.0.0/apksigner'
        apk = android / 'app/build/outputs/apk/release/app-release.apk'
        fixture_apk = self.root / 'disposable-fixture.apk'
        shutil.move(apk, fixture_apk)
        subprocess.run([str(apksigner), 'verify', '--verbose', str(fixture_apk)],
                       env=self.env, capture_output=True, check=True)


if __name__ == '__main__':
    unittest.main()
