#!/bin/sh
set -e

chown -R gophish:gophish /opt/gophish/data

exec gosu gophish "$@"
