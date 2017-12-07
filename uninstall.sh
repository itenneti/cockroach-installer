#!/bin/bash

APP_FILE="/usr/local/bin/cockroach"
ETCD_DIR="/etc/cockroachdb"
SYSTEMD_FILE="/etc/systemd/system/cockroach.service"
DATA_DIR="/var/data/cockroachdb"

if [ -f "$SYSTEMD_FILE" ]; then
  echo "Stopping cockroach service and removing from systemd"
  systemctl stop cockroach.service >/dev/null
  rm -f "$SYSTEMD_FILE"
  systemctl daemon-reload
fi

if [ -f "$APP_FILE" ]; then
  echo "Removing binary $APP_FILE"
  rm -f "$APP_FILE"
fi

if [ -d "$ETCD_DIR" ]; then
  echo "Removing directory $ETCD_DIR"
  rm -rf "$ETCD_DIR"
fi

if [ -f "/usr/local/bin/sql" ]; then
  rm "/usr/local/bin/sql"
fi

echo "Note: The directory $DATA_DIR is left intact, run 'rm -rf $DATA_DIR' if you wish to delete"
echo "Successful uninstall"
exit 0
