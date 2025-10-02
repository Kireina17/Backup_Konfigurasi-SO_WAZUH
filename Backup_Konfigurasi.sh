#!/usr/bin/env bash
set -e

TARGET="/mnt/backup/Backup_Konfigurasi"
REPORT_DIR="/home/kres/Backup_Konfigurasi"
NOW="$(date '+%Y-%m-%d %H:%M:%S')"
DATE="$(date '+%Y-%m-%d')"
REPORT_FILE="${REPORT_DIR}/${DATE}-backupkonfigurasi.txt"

# Pastikan folder report & target ada (termasuk rsyslog.d)
mkdir -p "$REPORT_DIR"
mkdir -p \
  "$TARGET/nsm/backup" \
  "$TARGET/nsm/wazuh/etc" \
  "$TARGET/nsm/wazuh/ruleset" \
  "$TARGET/nsm/wazuh/var/db" \
  "$TARGET/opt/so/conf" \
  "$TARGET/opt/so/saltstack" \
  "$TARGET/nsm/wazuh" \
  "$TARGET/etc/rsyslog.d"

# ===== Header Report + Size Sumber + Disk sebelum =====
{
  echo "========== BACKUP REPORT =========="
  echo "Tanggal & Jam : $NOW"
  echo "Target        : $TARGET"
  echo

  echo "[*] Ukuran Sumber:"
  du -sh \
    /nsm/backup \
    /nsm/wazuh/etc \
    /nsm/wazuh/ruleset \
    /nsm/wazuh/var/db \
    /opt/so/conf \
    /opt/so/saltstack \
    /nsm/wazuh \
    /etc/rsyslog.d 2>/dev/null
  total_src=$(
    du -sb \
      /nsm/backup \
      /nsm/wazuh/etc \
      /nsm/wazuh/ruleset \
      /nsm/wazuh/var/db \
      /opt/so/conf \
      /opt/so/saltstack \
      /nsm/wazuh \
      /etc/rsyslog.d 2>/dev/null | awk '{s+=$1} END {print s}'
  )
  echo "   Total sumber : $(numfmt --to=iec --suffix=B $total_src)"
  echo

  echo "[*] Kondisi Disk di /mnt/backup (sebelum backup):"
  df -h /mnt/backup | tail -1 | awk '{print "    Size: "$2"  Used: "$3"  Avail: "$4"  Use%: "$5}'
  echo
} > "$REPORT_FILE"

STATUS="SUCCESS"

run_rsync() {
  SRC=$1; DST=$2; DESC=$3; shift 3

  echo "[*] Backup $DESC ..." | tee -a "$REPORT_FILE"

  # Lindungi dari set -e: jangan keluar saat rsync return non-zero
  set +e
  rsync -aHAX --numeric-ids --sparse --compress --info=progress2 \
       "$@" "$SRC" "$DST" >> /var/log/backup_wazuh.log 2>&1
  rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    echo "    -> $DESC OK" | tee -a "$REPORT_FILE"
  elif [[ $rc -eq 24 ]]; then
    echo "    -> $DESC OK (ada file yang hilang saat disalin, normal)" | tee -a "$REPORT_FILE"
  else
    echo "    -> $DESC FAILED (exit code $rc)" | tee -a "$REPORT_FILE"
    STATUS="FAILED"
  fi
}

# ===== Daftar backup (rsyslog lebih dulu, baru wazuh) =====
run_rsync "/nsm/backup/"        "$TARGET/nsm/backup/"        "/nsm/backup"
run_rsync "/nsm/wazuh/etc/"     "$TARGET/nsm/wazuh/etc/"     "/nsm/wazuh/etc"
run_rsync "/nsm/wazuh/ruleset/" "$TARGET/nsm/wazuh/ruleset/" "/nsm/wazuh/ruleset"
run_rsync "/nsm/wazuh/var/db/"  "$TARGET/nsm/wazuh/var/db/"  "/nsm/wazuh/var/db"
run_rsync "/opt/so/conf/"       "$TARGET/opt/so/conf/"       "/opt/so/conf"
run_rsync "/opt/so/saltstack/"  "$TARGET/opt/so/saltstack/"  "/opt/so/saltstack"
run_rsync "/etc/rsyslog.d/"     "$TARGET/etc/rsyslog.d/"     "/etc/rsyslog.d"
run_rsync "/nsm/wazuh/"         "$TARGET/nsm/wazuh/"         "/nsm/wazuh (exclude logs)" \
  --exclude='logs/alerts/' --exclude='logs/archives/'

# ===== Size Hasil + Disk sesudah =====
{
  echo
  echo "[*] Ukuran Hasil Backup:"
  du -sh \
    "$TARGET/nsm/backup" \
    "$TARGET/nsm/wazuh/etc" \
    "$TARGET/nsm/wazuh/ruleset" \
    "$TARGET/nsm/wazuh/var/db" \
    "$TARGET/opt/so/conf" \
    "$TARGET/opt/so/saltstack" \
    "$TARGET/nsm/wazuh" \
    "$TARGET/etc/rsyslog.d" 2>/dev/null
  total_dst=$(
    du -sb \
      "$TARGET/nsm/backup" \
      "$TARGET/nsm/wazuh/etc" \
      "$TARGET/nsm/wazuh/ruleset" \
      "$TARGET/nsm/wazuh/var/db" \
      "$TARGET/opt/so/conf" \
      "$TARGET/opt/so/saltstack" \
      "$TARGET/nsm/wazuh" \
      "$TARGET/etc/rsyslog.d" 2>/dev/null | awk '{s+=$1} END {print s}'
  )
  echo "   Total backup : $(numfmt --to=iec --suffix=B $total_dst)"
  echo

  echo "[*] Kondisi Disk di /mnt/backup (sesudah backup):"
  df -h /mnt/backup | tail -1 | awk '{print "    Size: "$2"  Used: "$3"  Avail: "$4"  Use%: "$5}'
  echo

  echo "Hasil Backup : $STATUS"
  echo "===================================="
  echo
  echo "@dahfa2025"
} >> "$REPORT_FILE"

