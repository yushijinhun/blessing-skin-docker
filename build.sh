#!/bin/bash
set -e
shopt -s dotglob

# Update local repository
if [ ! -d upstream ]; then
	git --bare init upstream
	git --git-dir=upstream remote add origin "https://github.com/printempw/blessing-skin-server"
fi
git --git-dir=upstream fetch --prune --prune-tags --tags origin "+refs/heads/*:refs/remotes/origin/*"

revision=$(<revision)
image="blessing-skin-server:$revision"

rm -rf build
mkdir -p build
git --git-dir=upstream --work-tree=build checkout "$revision" -- .

cp -r src/* build/
sudo docker build --pull -t "$image" build

mkdir -p images
image_save="images/$image.tar.xz"
sudo docker save "$image" | xz -9 > "images/$image.tar.xz"

echo "Image $image is built and saved to $image_save"
