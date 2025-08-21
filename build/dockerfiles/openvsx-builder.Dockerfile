# Copyright (c) 2022-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# https://registry.access.redhat.com/ubi8/ubi
FROM registry.access.redhat.com/ubi8/ubi:8.9-1028 as builder

RUN yum install java-17-openjdk-devel git jq unzip curl -y --nodocs && \
    yum update -q -y 

ARG OPENVSX_VERSION
ENV OPENVSX_VERSION=${OPENVSX_VERSION}

ARG CHE_CODE_VERSION
ENV CHE_CODE_VERSION=${CHE_CODE_VERSION}

RUN cd /tmp; \
    git clone https://github.com/eclipse/openvsx.git; \
    cd /tmp/openvsx; \
    git checkout ${OPENVSX_VERSION};

RUN cd /tmp/openvsx/server && ./gradlew --no-daemon assemble && \
    mkdir /openvsx-server && \
    cp /tmp/openvsx/server/scripts/run-server.sh /openvsx-server && \
    cp /tmp/openvsx/server/build/libs/openvsx-server.jar /openvsx-server


RUN cd /openvsx-server && jar -xf openvsx-server.jar && rm openvsx-server.jar

COPY /openvsx-sync.json /openvsx-server/
COPY /build/scripts/download_vsix.sh /tmp
RUN \
    # Pull vsix files from openvsx
    /tmp/download_vsix.sh -e $CHE_CODE_VERSION && mv /tmp/vsix /openvsx-server

RUN tar -czvf openvsx-server.tar.gz openvsx-server \
