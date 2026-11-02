#!/usr/bin/env python3
"""Exercise real desktop install/update/uninstall code without touching player data.

Use Godot 3.6.1, not Godot 4. On Windows pass the console executable and keep
its sibling runtime executable beside it. --live additionally checks current
published packages; it never promotes their gameplay validation status.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--live', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='ccb-godot3-acceptance-') as temporary:
        sandbox = Path(temporary).resolve()
        binary = sandbox / args.godot.name
        shutil.copy2(args.godot, binary)
        if os.name == 'nt':
            for sibling in args.godot.parent.glob('*.exe'):
                if sibling.name != binary.name:
                    shutil.copy2(sibling, sandbox / sibling.name)
        (sandbox / 'utils').mkdir()
        for name in ('7za', '7za.exe'):
            shutil.copy2(ROOT / 'utils' / name, sandbox / 'utils' / name)
        (sandbox / 'game/data/mods').mkdir(parents=True)
        packages = sandbox / 'packages'
        packages.mkdir()
        catalog = {'schema_version': 1, 'mods': []}
        for mod_id, kind in [('hello_ccb', 'ccb-maintained'), ('community_test', 'community')]:
            catalog['mods'].append({
                'id': mod_id, 'type': kind, 'name': {'en': mod_id},
                'description': {'en': 'Private acceptance fixture, never published'},
                'version': '1', 'download': 'https://example.invalid/test.zip',
                'source': 'https://example.invalid/test', 'ccb_versions': ['test'],
            })
            with zipfile.ZipFile(packages / f'{mod_id}-1.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
                archive.writestr(f'{mod_id}/main.lua', 'return {}\n')
        catalog_path = sandbox / 'catalog.json'
        catalog_path.write_text(json.dumps(catalog), encoding='utf-8')
        env = dict(os.environ, CCB_TEST_SANDBOX=sandbox.as_posix(),
                   CCB_TEST_GAME=(sandbox / 'game').as_posix(),
                   CCB_TEST_PACKAGES=packages.as_posix(),
                   CCB_TEST_CATALOG=catalog_path.as_posix(),
                   CCB_TEST_ZIP=(packages / 'hello_ccb-1.zip').as_posix())
        # Autoloads write settings next to the copied engine, not the real launcher.
        def run(*arguments):
            # The editor can start adb, whose daemon inherits stdout. A PIPE
            # then never reaches EOF even after Godot exits on a fresh runner.
            # Use a log file so completion follows Godot, not its daemon's pipe.
            with tempfile.TemporaryFile(mode='w+', encoding='utf-8', errors='replace') as log:
                try:
                    video = ['--video-driver', 'GLES2'] if os.name == 'nt' else []
                    result = subprocess.run([str(binary), *video, '--path', str(ROOT), *arguments],
                                            env=env, stdout=log, stderr=log, timeout=180)
                finally:
                    log.seek(0)
                    output = log.read()
                    print(output, flush=True)
            if result.returncode or 'SCRIPT ERROR:' in output:
                raise RuntimeError(f'Godot failed: {arguments} (exit {result.returncode})')
        run('--editor', '--quit')
        for script in ('ccb_registry_smoke', 'ccb_catalog_ui', 'ccb_registry_install', 'ccb_catalog_packages'):
            run('--script', f'tests/{script}.gd')
        if args.live:
            url = 'https://crimsoncrossbunker.github.io/CCB-MOD/mods.json'
            with urllib.request.urlopen(url, timeout=30) as response:
                live = json.load(response)
            for mod in live['mods']:
                # Restrict the remote-derived destination filename before any write.
                import re
                if not re.fullmatch(r'[A-Za-z0-9_-]+', mod['id']) or not re.fullmatch(r'[A-Za-z0-9_.+-]+', mod['version']):
                    raise ValueError('Unsafe package filename')
                if not mod['download'].startswith('https://'):
                    raise ValueError('Non-HTTPS package')
                with urllib.request.urlopen(mod['download'], timeout=60) as response:
                    (packages / f"{mod['id']}-{mod['version']}.zip").write_bytes(response.read())
            catalog_path.write_text(json.dumps(live), encoding='utf-8')
            run('--script', 'tests/ccb_catalog_packages.gd')
        print('PASS: isolated desktop registry acceptance')


if __name__ == '__main__':
    main()
