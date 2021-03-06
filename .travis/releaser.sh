#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2018 Pawel Krupa (@paulfantom) - All Rights Reserved
# Permission to copy and modify is granted under the MIT license
#
# Original script is available at https://github.com/paulfantom/travis-helper/blob/master/releasing/releaser.sh
#
# Script to automatically do a couple of things:
#   - generate a new tag according to semver (https://semver.org/)
#   - generate CHANGELOG.md by using https://github.com/skywinder/github-changelog-generator
#   - create draft of GitHub releases by using https://github.com/github/hub
#
# Tags are generated by searching for a keyword in last commit message. Keywords are:
#  - [patch] or [fix] to bump patch number
#  - [minor], [feature] or [feat] to bump minor number
#  - [major] or [breaking change] to bump major number
# All keywords MUST be surrounded with square braces.
#
# Script uses git mechanisms for locking, so it can be used in parallel builds
#
# Requirements:
#   - GITHUB_TOKEN variable set with GitHub token. Access level: repo.public_repo
#   - docker
#   - git-semver python package (pip install git-semver)

set -e

if [ ! -f .gitignore ]; then
	echo "Run as ./travis/$(basename "$0") from top level directory of git repository"
	exit 1
fi

export GIT_MAIL="pawel+bot@netdata.cloud"
export GIT_USER="netdatabot"
echo "--- Initialize git configuration ---"
git config user.email "${GIT_MAIL}"
git config user.name "${GIT_USER}"

echo "---- FIGURING OUT TAGS ----"
./.travis/tagger.sh || exit 0

echo "---- GENERATING CHANGELOG -----"
./.travis/generate_changelog.sh

echo "---- CREATING TAGGED DOCKER CONTAINERS ----"
export REPOSITORY="netdata/netdata"
./docker/build.sh

echo "---- CREATING RELEASE ARTIFACTS -----"
./.travis/create_artifacts.sh

echo "---- CREATING RELEASE DRAFT WITH ASSETS -----"
# Download hub
HUB_VERSION=${HUB_VERSION:-"2.5.1"}
wget "https://github.com/github/hub/releases/download/v${HUB_VERSION}/hub-linux-amd64-${HUB_VERSION}.tgz" -O "/tmp/hub-linux-amd64-${HUB_VERSION}.tgz"
tar -C /tmp -xvf "/tmp/hub-linux-amd64-${HUB_VERSION}.tgz"
export PATH=$PATH:"/tmp/hub-linux-amd64-${HUB_VERSION}/bin"

# Create a release draft
hub release create --draft -a "netdata-${GIT_TAG}.tar.gz" -a "netdata-${GIT_TAG}.gz.run" -a "sha256sums.txt" -m "${GIT_TAG}" "${GIT_TAG}"
