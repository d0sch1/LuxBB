#!/bin/bash
set -euo pipefail
cd /home/d0sch1/forum
forum=$(sg docker -c "docker-compose ps -q forum" | head -n1 || true)
db=$(sg docker -c "docker-compose ps -q db" | head -n1 || true)

if [ -z "$forum" ] || [ -z "$db" ]; then
  echo "HEALTH: DOWN forum=${forum:-missing} db=${db:-missing}"
  exit 1
fi

forum_state=$(sg docker -c "docker inspect --format '{{.State.Status}}' $forum" || true)
db_state=$(sg docker -c "docker inspect --format '{{.State.Status}}' $db" || true)
if [ "$forum_state" != "running" ] || [ "$db_state" != "running" ]; then
  echo "HEALTH: NOT_RUNNING forum=$forum_state db=$db_state"
  exit 1
fi

db_usage=$(sg docker -c "docker exec $db df /var/lib/mysql | awk 'NR==2{print \$5}' | tr -d '%'" || echo 0)
if [ "$db_usage" -gt 85 ]; then
  echo "HEALTH: DB_DISK_HIGH ${db_usage}%"
  exit 1
fi

echo "HEALTH: OK forum=$forum_state db=$db_state db_usage=${db_usage}%"
