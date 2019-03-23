#!/bin/bash

# === blessing-skin-server 文件存储示意 ===
# 图示：
# DATA        数据（对业务有影响，需要持久化）
# CACHE       缓存（对业务无影响，不需要持久化）
# LOG         日志（链接到标准输出）
# UNUSED      未使用（暂不需要持久化）
# FIXED       此目录下不会出现未列出的目录
# X -> {path} 表示该目录或文件软链接到 /var/lib/blessing-skin-server/{path}
#
# /var/www/blessing-skin-server
# ├── plugins              # DATA -> plugins
# ├── storage              # FIXED
# │   ├── app              # FIXED
# │   │   └── public       # UNUSED
# │   ├── debugbar         # CACHE
# │   ├── framework        # FIXED
# │   │   ├── cache        # CACHE
# │   │   ├── sessions     # DATA -> data/sessions
# │   │   └── views        # CACHE
# │   ├── logs
# │   │   └── laravel.log  # LOG
# │   ├── testing          # CACHE
# │   ├── textures         # DATA -> data/textures
# │   ├── update_cache     # CACHE
# │   └── yaml-translation # CACHE
# └── .env                 # DATA -> .env
#
# /var/lib/blessing-skin-server # 此目录挂载为 VOLUME，是数据持久化的场所
# ├── data
# │   ├── database.db
# │   ├── sessions
# │   └── textures
# ├── plugins
# └── .env
#

set -e

while [[ $# -gt 0 ]]; do
	option=$1
	shift
	case $option in
		--disable-force-https)
			DISABLE_FORCE_HTTPS=true
			;;
	esac
done


WWW_DIR="/var/www/blessing-skin-server"
DATA_DIR="/var/lib/blessing-skin-server"
PHP_FPM_SOCKET="/var/run/php-fpm.sock"
PHP_USER="www"
NGINX_USER="nginx"

NGINX_EXTRA_CONF="/var/lib/blessing-skin-server/nginx/server.conf"

function set_owner() {
	chown "$PHP_USER:$PHP_USER" "$1"
}

# link_dir {src} {target}
function link_dir() {
	mkdir -p "$(dirname "$1")"
	if [ ! -L "$1" ] && [ -d "$1" ]; then
		rmdir "$1" || {
			echo "$1 is not empty!"
			exit 1
		}
	fi
	mkdir -p "$2"
	ln -sfn "$2" "$1"
	set_owner "$2"
}

link_dir "$WWW_DIR/plugins"                       "$DATA_DIR/plugins"
link_dir "$WWW_DIR/storage/framework/sessions"    "$DATA_DIR/data/sessions"
link_dir "$WWW_DIR/storage/textures"              "$DATA_DIR/data/textures"

ENV_CONFIG="$DATA_DIR/.env"
if [ ! -f "$ENV_CONFIG" ]; then
	echo "Initializing default .env at $ENV_CONFIG..."
	mkdir -p "$(dirname "$ENV_CONFIG")"
	cp "$WWW_DIR/.env.docker" "$ENV_CONFIG"
	set_owner "$ENV_CONFIG"
fi
ln -sfn "$ENV_CONFIG" "$WWW_DIR/.env"

DATABASE="$DATA_DIR/data/database.db"
if [ ! -f "$DATABASE" ]; then
	if grep -q "^\s*DB_CONNECTION\s*=\s*sqlite\s*$" "$ENV_CONFIG" && grep -q "^\s*DB_DATABASE\s*=\s*$DATABASE\s*$" "$ENV_CONFIG"; then
		echo "Initializing empty database at $DATABASE..."
		DATABASE_PARENT="$(dirname "$DATABASE")"
		mkdir -p "$DATABASE_PARENT"
		set_owner "$DATABASE_PARENT"
		touch "$DATABASE"
		set_owner "$DATABASE"
	fi # 否则用户在使用自定义的数据库
fi

mkdir -p "$(dirname "$NGINX_EXTRA_CONF")"
touch "$NGINX_EXTRA_CONF"
set_owner "$NGINX_EXTRA_CONF"

export LOG_CHANNEL=errorlog

function onexit() {
	killall -s SIGINT php-fpm7
}
php-fpm7
trap onexit EXIT
chmod 660 "$PHP_FPM_SOCKET"
chgrp "$NGINX_USER" "$PHP_FPM_SOCKET"
nginx # blocking

