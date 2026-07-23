#!/bin/bash
set -euo pipefail
cd /home/d0sch1/forum
forum=$(sg docker -c "docker-compose ps -q forum" | head -n1 || true)
if [ -z "$forum" ]; then
  echo "forum container not found"
  exit 1
fi
count=$(sg docker -c "docker logs $forum 2>&1 | tail -200" | grep -ciE '\[error\]|PHP (Fatal|Parse) Error|Exception' || true)
if [ "$count" -gt 0 ]; then
  echo "ALERT: $count recent error/PHP-fatal entries detected in forum logs"
  sg docker -c "docker logs $forum 2>&1 | tail -200" | grep -iE '\[error\]|PHP (Fatal|Parse) Error|Exception' | tail -20 || true
  exit 1
else
  echo "OK: no recent severe errors"
fi
