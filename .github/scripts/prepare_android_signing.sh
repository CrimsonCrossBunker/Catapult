#!/usr/bin/env bash
# Never enable shell tracing here. Secret values belong only in the environment.
set +x
set -euo pipefail
umask 077

for name in KEYSTORE KEYSTORE_PROPERTIES KEYSTORE_PASSWORD CCB_ANDROID_SIGNING_DIR; do
    if [[ -z "${!name:-}" ]]; then
        echo "Missing Android signing input: $name" >&2
        exit 1
    fi
done

# The caller owns this temporary directory and removes it on every exit path.
[[ -d "$CCB_ANDROID_SIGNING_DIR" && ! -L "$CCB_ANDROID_SIGNING_DIR" ]] || exit 1
for name in release.keystore keystore.properties release.keystore.asc keystore.properties.asc; do
    if [[ -e "$CCB_ANDROID_SIGNING_DIR/$name" || -L "$CCB_ANDROID_SIGNING_DIR/$name" ]]; then
        echo 'Signing destination is not empty; refusing to overwrite files.' >&2
        exit 1
    fi
done

printf '%s' "$KEYSTORE" > "$CCB_ANDROID_SIGNING_DIR/release.keystore.asc"
printf '%s' "$KEYSTORE_PROPERTIES" > "$CCB_ANDROID_SIGNING_DIR/keystore.properties.asc"
for name in release.keystore keystore.properties; do
    if ! gpg --batch --yes --quiet --no-symkey-cache --pinentry-mode loopback --passphrase-fd 3 \
        --output "$CCB_ANDROID_SIGNING_DIR/$name" \
        --decrypt "$CCB_ANDROID_SIGNING_DIR/$name.asc" \
        3<<<"$KEYSTORE_PASSWORD" 2>/dev/null; then
        echo 'Android signing decryption failed; verify the three shared Secrets.' >&2
        exit 1
    fi
    [[ -s "$CCB_ANDROID_SIGNING_DIR/$name" ]] || exit 1
done
