#!/bin/bash
set -e

if [[ $(echo "$1" | cut -c1) = "-" ]]; then
  echo "$0: assuming arguments for omnicored"

  set -- omnicored "$@"
fi

if [[ $(echo "$1" | cut -c1) = "-" ]] || [[ "$1" = "omnicored" ]]; then
  mkdir -p "$DATA_DIR"
  chmod 700 "$DATA_DIR"

  echo "$0: setting data directory to $DATA_DIR"

  set -- "$@" -datadir="$DATA_DIR"
fi

if [[ "$1" = "omnicored" ]] || [[ "$1" = "omnicore-cli" ]] || [[ "$1" = "bitcoin-tx" ]]; then
  echo
  exec "$@"
fi

echo
exec "$@"
