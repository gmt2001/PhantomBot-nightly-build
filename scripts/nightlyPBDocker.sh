#!/bin/bash
#
# Copyright (C) 2016-2020 phantombot.tv
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
# nightlyPBDocker.sh
#
# Performs the Nightly Docker Build of PhantomBot.

MASTER="${HOME}/PhantomBot"
DOCKER_BUILD="/opt/PhantomBot"
DATE=$(date +%m%d%Y)

cd ${HOME}

git clone --progress --depth=1 https://github.com/PhantomBot/PhantomBot.git
cd PhantomBot
PB_VERSION=$(grep "property name=\"version\"" build.xml | perl -e 'while(<STDIN>) { ($ver) = $_ =~ m/\s+<property name=\"version\" value=\"(.*)\" \/>/; } print $ver;')
ant -noinput -buildfile build.xml distclean

REPO_VERSION=$(git rev-parse --short HEAD)
PBFOLDER=PhantomBot-${PB_VERSION}-NB-${DATE}

URI="https://registry.hub.docker.com/v2/repositories/${DOCKER_REPO}/tags/${REPO_VERSION}/"

HTTPCODE=$(curl -s -I "${URI}" | head -n 1 | cut  -d$' ' -f2)

if [[ "${HTTPCODE}" = "200" ]]; then
    echo Build already published
    exit 0
else
    echo Build not published ${HTTPCODE}
fi

mkdir -p ${DOCKER_BUILD}
cp -rf ${MASTER}/* ${DOCKER_BUILD}
cd ${DOCKER_BUILD}

rm -rf resources/java-runtime
rm -rf resources/java-runtime-macos

sed -i "s/<target name=\"git.revision\" if=\"git.present\">/<target name=\"git.revision\">/" build.xml
sed -i "s/else=\"unknown\">/else=\"${REPO_VERSION}\">/" build.xml
sed -i -r "s/revision=\"[A-Za-z0-9._-]+\"/revision=\"${REPO_VERSION}\"/;s/branch=\"[A-Za-z0-9._-]+\"/branch=\"${PB_VERSION}-NB-${DATE}\"/" ivy.xml

docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 --file Dockerfile -t ${DOCKER_REPO}:${REPO_VERSION} --build-arg PROJECT_VERSION=${PB_VERSION}-NB-${DATE} --build-arg ANT_ARGS="-Dbuildtype=nightly_build -Drollbar_token=${ROLLBAR_TOKEN} -Drollbar_endpoint=${ROLLBAR_ENDPOINT} -Dversion=${PB_VERSION}-NB-${DATE}" --push .
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 --file Dockerfile -t ${DOCKER_REPO}:latest --build-arg PROJECT_VERSION=${PB_VERSION}-NB-${DATE} --build-arg ANT_ARGS="-Dbuildtype=nightly_build -Drollbar_token=${ROLLBAR_TOKEN} -Drollbar_endpoint=${ROLLBAR_ENDPOINT} -Dversion=${PB_VERSION}-NB-${DATE}" --push .
