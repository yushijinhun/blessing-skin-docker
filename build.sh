#!/bin/bash
set -e
shopt -s dotglob

if [[ "$SKIP_UPDATE" != "true" ]]; then
	# Update local repository
	if [ ! -d upstream ]; then
		git --bare init upstream
		git --git-dir=upstream remote add origin "https://github.com/printempw/blessing-skin-server"
	fi
	git --git-dir=upstream fetch --prune --prune-tags --tags origin "+refs/heads/*:refs/remotes/origin/*"
fi

revision=$(<revision)
image="yushijinhun/blessing-skin-server:$revision"

rm -rf build
mkdir -p build/src
git --git-dir=upstream --work-tree=build/src checkout "$revision" -- .

cp -r src/* build/
sudo docker build -t "$image" $DOCKER_OPTS build

sudo docker tag "$image" "yushijinhun/blessing-skin-server:latest"

if [[ "$SKIP_BUNDLING" != "true" ]]; then
	mkdir -p images
	image_save="images/$revision.tar.xz"
	sudo docker save "$image" | xz -9 > "$image_save"
	echo "Image $image is built and saved to $image_save"
fi
