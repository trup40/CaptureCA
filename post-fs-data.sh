#!/system/bin/sh

exec > /data/local/tmp/CaptureCA.log
exec 2>&1

MODDIR=${0%/*}

set_context() {
    [ "$(getenforce)" = "Enforcing" ] || return 0

    default_selinux_context=u:object_r:system_file:s0
    selinux_context=$(ls -Zd $1 | awk '{print $1}')

    if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
        chcon -R $selinux_context $2
    else
        chcon -R $default_selinux_context $2
    fi
}

echo "[$(date +%F) $(date +%T)] - CaptureCA post-fs-data.sh start."
chown -R 0:0 ${MODDIR}/system/etc/security/cacerts

if [ -d /apex/com.android.conscrypt/cacerts ]; then
    # Android 14 and up (Conscrypt APEX) detection
    CERT_DIR=${MODDIR}/system/etc/security/cacerts
    
    # check if dir is empty
    if [ -z "$(ls -A $CERT_DIR)" ]; then
        echo "[$(date +%F) $(date +%T)] - No certificates found in module."
        exit 0
    fi

    TEMP_DIR=/data/local/tmp/cacerts-copy
    rm -rf "$TEMP_DIR"
    mkdir -p -m 700 "$TEMP_DIR"
    mount -t tmpfs tmpfs "$TEMP_DIR"

    # copy originals to temp dir
    cp -f /apex/com.android.conscrypt/cacerts/* "$TEMP_DIR"
    
    # copy all from module dir to temp
    cp -f $CERT_DIR/* "$TEMP_DIR"

    chown -R 0:0 "$TEMP_DIR"
    set_context /apex/com.android.conscrypt/cacerts "$TEMP_DIR"

    # check if copy is ok
    CERTS_NUM="$(ls -1 "$TEMP_DIR" | wc -l)"
    if [ "$CERTS_NUM" -gt 10 ]; then
        mount -o bind "$TEMP_DIR" /apex/com.android.conscrypt/cacerts
         for pid in 1 $(pgrep zygote) $(pgrep zygote64); do
            nsenter --mount=/proc/${pid}/ns/mnt -- \
                mount --bind "$TEMP_DIR" /apex/com.android.conscrypt/cacerts
        done
        echo "[$(date +%F) $(date +%T)] - Mount success!"
    else
        echo "[$(date +%F) $(date +%T)] - Mount failed!"
    fi

    # clean temp
    umount "$TEMP_DIR"
    rmdir "$TEMP_DIR"
else
    # Android 13 and down, mounting bla bla
    echo "[$(date +%F) $(date +%T)] - Android version lower than 14 detected"
    set_context /system/etc/security/cacerts ${MODDIR}/system/etc/security/cacerts 
    echo "[$(date +%F) $(date +%T)] - Context set success!"
fi