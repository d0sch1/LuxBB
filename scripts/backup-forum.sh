#!/bin/bash
# Forum backup: DB dump + secrets + meme volume + src patches, mirrored off-host.
set -euo pipefail

FORUM_DIR="/home/d0sch1/forum"
BACKUP_DIR="${FORUM_DIR}/backups"
# Separate physical disk (sdb1) — survives a failure of the root disk.
OFFHOST_DIR="/mnt/data/forum-backups"
# Real docker volume name (compose prefixes the project name "forum_" onto "forum-memes").
MEME_VOLUME="forum_forum-memes"
DB_CONTAINER="forum-db"
RETENTION_DAYS=14

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR" "$OFFHOST_DIR"
cd "$FORUM_DIR"

DB_PASS=$(cat secrets/db_password.txt)

# 1) Database dump (written 600 immediately)
DUMP="${BACKUP_DIR}/fluxbb-${TIMESTAMP}.sql.gz"
sg docker -c "docker exec ${DB_CONTAINER} mysqldump -u fluxbb -p${DB_PASS} fluxbb" \
  | gzip > "$DUMP"
chmod 600 "$DUMP"

# 2) Secrets
cp -a secrets/db_password.txt secrets/db_root_password.txt "$BACKUP_DIR/"
chmod 600 "$BACKUP_DIR"/db_*.txt

# 3) Meme volume (named docker volume) -> tar via throwaway busybox.
# Pipe to stdout so the shell redirect creates the file as d0sch1 (container would
# otherwise write it as root and we couldn't chmod/retain it).
MEMES_TAR="${BACKUP_DIR}/forum-memes-${TIMESTAMP}.tar.gz"
sg docker -c "docker run --rm -v ${MEME_VOLUME}:/data busybox tar czf - -C /data ." > "$MEMES_TAR"
chmod 600 "$MEMES_TAR"

# 4) src/ working tree (the two custom patches + register-token gate are uncommitted in git)
#    Tar the live tree as source of truth; skip the .git dir to keep it small.
SRC_TAR="${BACKUP_DIR}/forum-src-${TIMESTAMP}.tar.gz"
tar czf "$SRC_TAR" -C "$FORUM_DIR" --exclude='src/.git' src
chmod 600 "$SRC_TAR"

# 5) Mirror everything to the off-host disk (separate physical device)
cp -a "$DUMP" "$BACKUP_DIR"/db_*.txt "$MEMES_TAR" "$SRC_TAR" "$OFFHOST_DIR"/

# 6) Retention
find "$BACKUP_DIR" -name 'fluxbb-*.sql.gz'        -mtime +${RETENTION_DAYS} -delete
find "$BACKUP_DIR" -name 'db_*.txt'               -mtime +${RETENTION_DAYS} -delete
find "$BACKUP_DIR" -name 'forum-memes-*.tar.gz'   -mtime +${RETENTION_DAYS} -delete
find "$BACKUP_DIR" -name 'forum-src-*.tar.gz'     -mtime +${RETENTION_DAYS} -delete
find "$OFFHOST_DIR" -name 'fluxbb-*.sql.gz'       -mtime +${RETENTION_DAYS} -delete
find "$OFFHOST_DIR" -name 'db_*.txt'              -mtime +${RETENTION_DAYS} -delete
find "$OFFHOST_DIR" -name 'forum-memes-*.tar.gz'  -mtime +${RETENTION_DAYS} -delete
find "$OFFHOST_DIR" -name 'forum-src-*.tar.gz'    -mtime +${RETENTION_DAYS} -delete

echo "backup done $(date) (db+secrets+memes+src; mirrored to ${OFFHOST_DIR})"
