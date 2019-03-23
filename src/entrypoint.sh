#!/bin/bash
set -e

WWW_DIR="/var/www/blessing-skin-server"
DATA_DIR="/var/lib/blessing-skin-server"
PHP_FPM_SOCKET="/var/run/php-fpm.sock"
PHP_USER="www"
NGINX_USER="nginx"

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
link_dir "$WWW_DIR/public/plugins"                "$DATA_DIR/plugins-public"

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

export LOG_CHANNEL=errorlog

function onexit() {
	killall -s SIGINT php-fpm7
}
php-fpm7
trap onexit EXIT
chmod 660 "$PHP_FPM_SOCKET"
chgrp "$NGINX_USER" "$PHP_FPM_SOCKET"
nginx # blocking

