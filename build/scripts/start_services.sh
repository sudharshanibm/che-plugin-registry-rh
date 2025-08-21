#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

set -e
set -o pipefail

# start postgresql
pushd /var/lib/pgsql || return
/usr/bin/postgres &
# wait that postgresql is ready
printf "Waiting that postgresql is ready"
timeout 0 bash -c "until /usr/bin/pg_isready -h 127.0.0.1 -p 5432 -U postgres -q; do printf '.'; sleep 1; done"
echo "Database is ready"

# start openvsx
pushd /openvsx-server || return
./run-server.sh &
printf "Waiting that openvsx is ready"
timeout 0 bash -c "until curl --output /dev/null --head --silent --fail http://localhost:9000/user; do printf '.'; sleep 1; done"
printf "Openvsx is ready"
