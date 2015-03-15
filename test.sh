#!/bin/sh

. $(dirname $(readlink -f $0))/aeten-shell-log.sh

title Simple logging messages
info An information message
warn A warning message
error An error message

title Simple checks
check warn "No warning occured." return 0
check warn "A warning occured." return 1
check error "No error occured." return 0
check error "An error occured." return 1

title Check exit 1 on fatal error
( check fatal "A fatal error occured in a sub-shell." return 1 )
check fatal "Check if fatal error causes exit." test ${?} -eq 1

title Query and reply
answer=$( ( sleep 1;echo yes ) | query Will says '"yes"' in 1 second. )
check fatal 'Check if answer is "yes".' test "${answer}" = yes
