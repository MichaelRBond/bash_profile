#!/bin/bash

if [ -z ${1+x} ]; then
  echo "DSID is missing"
fi

dsid=$1

 sudo openconnect --juniper -C "DSID=${dsid}" vpnmfa.move.com
