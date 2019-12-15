#!/bin/bash

FILE=${@: -1}

if [ "${FILE##*.}" = "md" ]; then
  mdcat $@
else
  cat $@
fi
