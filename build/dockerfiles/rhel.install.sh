#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
set -x

# set same version in Dockerfiles, eg., base image ubi8/python-311
PYTHON_VERSION="3.11"
NODEJS_VERSION="18"

DNF="dnf -q"
# shellcheck disable=SC2086
if [[ ! -x $(command -v $DNF || true) ]]; then   DNF="yum -q"
  if [[ ! -x $(command -v $DNF || true) ]]; then DNF=microdnf; fi
fi

${DNF} -y install \
    python${PYTHON_VERSION} python${PYTHON_VERSION}-devel python${PYTHON_VERSION}-setuptools python${PYTHON_VERSION}-pip --exclude=unbound-libs || exit 1

# shellcheck disable=SC2010
PYTHON_BIN=$(ls -1 /usr/bin | grep -E "^python3.[0-9]+$" | sort -V | tail -1 || true) # 3.6, 3.7, 3.8, etc.
if [[ ! ${PYTHON_BIN} ]]; then
    PYTHON_BIN=python$(/usr/bin/python3 -V | sed -r -e "s#Python ##" -e "s#([0-9])\.([0-9]+)\.([0-9]+)#\1.\2#")
fi
if [[ ! -L /usr/bin/python ]]; then
    ln -s /usr/bin/"${PYTHON_BIN}" /usr/bin/python
fi

${DNF} -y install \
    java-17-openjdk httpd runc coreutils-single glibc-minimal-langpack glibc-langpack-en langpacks-en glibc-locale-source nc \
    net-tools procps vi wget tar gzip jq findutils bash git skopeo \
    --releasever 8 --nodocs

${DNF} -y module reset nodejs && \
    ${DNF} -y module enable nodejs:${NODEJS_VERSION} && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    ${DNF} install -y --setopt=tsflags=nodocs nodejs npm nodejs-nodemon nss_wrapper make gcc gcc-c++ libatomic_ops git openssl-devel && \
    ${DNF} -y update && ${DNF} -y clean all && rm -rf /var/cache/yum /var/log/dnf* /var/log/yum.* && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages"

# install yq (depends on jq and pyyaml - if jq and pyyaml not already installed, this will try to compile it)
if [[ -f /tmp/root-local.tgz ]] || [[ ${BOOTSTRAP} == "true" ]]; then
    # NOTE: for devfile registry, use /opt/app-root/src/.local instead of ~/.local
    mkdir -p "${HOME}"/.local
    if [[ -f /tmp/root-local.tgz ]]; then
        tar xf /tmp/root-local.tgz -C "${HOME}"/.local
        rm -fr /tmp/root-local.tgz
    fi
    /usr/bin/"${PYTHON_BIN}" -m pip install --user yq argcomplete pip --upgrade
    # shellcheck disable=SC2043
    for d in ${HOME}/.local; do
        if [[ -d ${d} ]]; then
            cp "${d}"/bin/yq /usr/local/bin/
            mkdir -p "${d}"/lib/"${PYTHON_BIN}"/site-packages/
            # shellcheck disable=SC2164
            pushd "${d}"/lib/"${PYTHON_BIN}"/site-packages/ >/dev/null
            cp -r PyYAML* xmltodict* yaml* yq* /usr/lib/"${PYTHON_BIN}"/site-packages/
            # shellcheck disable=SC2164
            popd >/dev/null
        fi
    done
    chmod -c +x /usr/local/bin/*
else
    /usr/bin/"${PYTHON_BIN}" -m pip install yq
fi
# test install worked
for d in python yq jq; do echo -n "$d: "; $d --version; done
