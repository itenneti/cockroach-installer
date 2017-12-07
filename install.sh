#!/bin/bash

APP_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
DATA_DIR="/var/data/cockroachdb"
ETC="/etc/cockroachdb"
CERT_DIR="$ETC/certs"
# CERT_PRIVATE_DIR="$CERT_DIR/private"

function usage {
  # printf "Cockroach DB Installer\n  Usage: JOIN=host1,host2 [DB=name] $1 /path/to/cockroachdb.tgz [user]\n"
  printf "Cockroach DB Installer\n\n  Usage: JOIN=host1,host2 CERTS=/path/to/certs $1 /path/to/cockroachdb.tgz [user]\n\n"
  echo "Download Cockroach DB tarball file from https://www.cockroachlabs.com/docs/stable/install-cockroachdb.html"
  echo "Note: Run this script as root!"
}

function extractRoach {
  echo "Extracting tarball $1"
  mkdir -p "$APP_DIR" || exit 1
  tar -xzf "$1" || exit 1
}

function setInstallDirs {
  echo "Installing cockroach binary in $APP_DIR and making data dir $DATA_DIR"
  filename=$(basename "$1")
  extension="${filename##*.}"
  filename="${filename%.*}"
  mv -f "$filename/cockroach" "$APP_DIR/cockroach" || exit 1
  rm -rf "$filename"
  mkdir -p "$DATA_DIR" || exit 1
}

# function installCerts {
#   echo "Creating certs in $CERT_DIR and $CERT_PRIVATE_DIR"
#   mkdir -p "$CERT_DIR" || exit 1
#   mkdir -p "$CERT_PRIVATE_DIR" || exit 1
#   "$APP_DIR/cockroach" cert create-ca --certs-dir="$CERT_DIR" --ca-key="$CERT_PRIVATE_DIR/ca.key" || exit 1
#   "$APP_DIR/cockroach" cert create-client root --certs-dir="$CERT_DIR" --ca-key="$CERT_PRIVATE_DIR/ca.key" || exit 1
#   "$APP_DIR/cockroach" cert create-node localhost $(hostname) --certs-dir="$CERT_DIR" --ca-key="$CERT_PRIVATE_DIR/ca.key" || exit 1
# }

function copyCerts {
  echo "Copying certs from $CERTS to $CERT_DIR"
  mkdir -p "$CERT_DIR" || exit 1
  cp -p $CERTS/* $CERT_DIR/ || exit 1
}

function changePerms {
  usr=$1
  if [ -z "$usr" ];then
    usr=$SUDO_USER
  fi
  if [ -z "$usr" ];then
    return
  fi
  echo "Changing ownership of $ETC to user $usr"
  chown -R "$usr:$usr" "$ETC" #remove the need for sudo when accessing cockroachdb
}

function installService {
  echo "Setting up systemd unit in $SYSTEMD_DIR"
  mkdir -p "$SYSTEMD_DIR" || exit 1
  hostname=$(hostname)
  # zone is last 3 chars of hostname e.g. db-n1-e1d = zone e1d
  zone=${hostname:(-3)}
  # region is first char of zone e.g. e1d = region e
  region=${zone:0:1}
  sed -e "s/REGION/$region/" -e "s/ZONE/$zone/" -e "s/JOIN/$JOIN/" -e "s/HOSTNAME/$hostname/" cockroach-cluster.service > "$SYSTEMD_DIR/cockroach.service"
  if [ ! -f "$SYSTEMD_DIR/cockroach.service" ]; then
    echo "Failed to write file $SYSTEMD_DIR/cockroach.service"
    exit 1
  fi
  # if [ -n "$DB" ]; then
  #   echo "Adding post-start script to create database $DB"
  #   sed -i "s/^ExecStartPost=$/ExecStartPost=\/usr\/local\/bin\/cockroach sql --certs-dir=\/etc\/cockroachdb\/certs -e \"CREATE DATABASE IF NOT EXISTS $DB;\"/" "$SYSTEMD_DIR/cockroach.service" || exit 1
  # fi
  systemctl enable cockroach.service || exit 1
}

# create sql bin for easier access to the sql console
function outputConnectUtil {
  echo "Creating convenience bin /usr/local/bin/sql"
  touch "/usr/local/bin/sql"
  cat <<EOF > /usr/local/bin/sql
#!/bin/bash
cockroach sql --certs-dir=/etc/cockroachdb/certs "$@"
EOF
  chmod +x "/usr/local/bin/sql"
}

## Begin processing script

if [ -z "$1" ]; then
  usage $0
  exit 1
fi

if [ -z "$JOIN" ]; then
  echo "You must specify which hosts to join via the JOIN var"
  exit 1
fi

if [ -z "$CERTS" ]; then
  echo "You must specify the location of certs via the CERTS var"
  exit 1
fi

./uninstall.sh

extractRoach $1
setInstallDirs $1
# installCerts
copyCerts
changePerms $2
installService
outputConnectUtil

echo "Successful install"
echo "Start cockroach via: systemctl start cockroach"
exit 0
