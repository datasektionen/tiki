#!/bin/bash

STATUS=$(nomad job inspect -namespace=metaspexet tiki 2>&1)

if [[ $STATUS == Error* ]]; then
    SECRET_ID=$(nomad login | grep "Secret ID" | sed -E "s/.*= *(.+)/\\1/")
    sed -i '' "s/^export NOMAD_TOKEN=.*/export NOMAD_TOKEN=$SECRET_ID/" .env
    export NOMAD_TOKEN=$SECRET_ID
fi

ALLOCATION_ID=$(nomad job allocs -namespace=metaspexet tiki | awk 'NR==2 {print $1}')
nomad exec -namespace metaspexet -task tiki $ALLOCATION_ID /app/bin/tiki remote
