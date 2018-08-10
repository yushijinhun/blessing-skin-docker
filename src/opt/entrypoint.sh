#!/bin/bash

# === blessing-skin-server 文件存储示意 ===
# 图示：
# DATA        数据（对业务有影响，需要持久化）
# CACHE       缓存（对业务无影响，不需要持久化）
# LOGS        日志（顾名思义，需要持久化）
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
# │   ├── logs             # LOGS -> logs/blessing-skin-server
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
# ├── logs
# │   └── blessing-skin-server
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

NGINX_CONF_TARGET="/etc/nginx/conf.d/blessing-skin-server.conf"
NGINX_CONF_HTTP="/opt/blessing-skin-server/nginx-http.conf"
NGINX_CONF_HTTPS_FORCE="/opt/blessing-skin-server/nginx-https-force.conf"
NGINX_CONF_HTTPS="/opt/blessing-skin-server/nginx-https.conf"

TLS_CERT="/etc/ssl/certs/bs.pem"
TLS_PK="/etc/ssl/private/bs.key"

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
link_dir "$WWW_DIR/storage/logs"                  "$DATA_DIR/logs/blessing-skin-server"
link_dir "$WWW_DIR/storage/textures"              "$DATA_DIR/data/textures"

# 若是新创建的 .env，则需要随机化 salt 和 app_key
GENERATE_KEYS=false

ENV_CONFIG="$DATA_DIR/.env"
if [ ! -f "$ENV_CONFIG" ]; then
	echo "Initializing default .env at $ENV_CONFIG..."
	mkdir -p "$(dirname "$ENV_CONFIG")"
	cp "$WWW_DIR/.env.docker" "$ENV_CONFIG"
	set_owner "$ENV_CONFIG"
	GENERATE_KEYS=true
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

if [ "$GENERATE_KEYS" = true ]; then
	pushd "$WWW_DIR" > /dev/null
	php artisan salt:random
	php artisan key:generate
	popd > /dev/null
fi

if [ -f "$TLS_CERT" ] && [ -f "$TLS_PK" ]; then
	if [[ "$DISABLE_FORCE_HTTPS" == "true" ]]; then
		ln -sf "$NGINX_CONF_HTTPS" "$NGINX_CONF_TARGET"
		echo "HTTPS enabled."
	else
		ln -sf "$NGINX_CONF_HTTPS_FORCE" "$NGINX_CONF_TARGET"
		echo "Force HTTPS enabled."
	fi
else
	ln -sf "$NGINX_CONF_HTTP" "$NGINX_CONF_TARGET"
fi

mkdir -p "$(dirname "$NGINX_EXTRA_CONF")"
touch "$NGINX_EXTRA_CONF"
set_owner "$NGINX_EXTRA_CONF"

function onexit() {
	killall -s SIGINT php-fpm7
}
php-fpm7
trap onexit EXIT
chmod 660 "$PHP_FPM_SOCKET"
chgrp "$NGINX_USER" "$PHP_FPM_SOCKET"
nginx # blocking

