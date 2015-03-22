#!/bin/sh
. $(dirname $0)/aeten-cli.sh
title Simple logging messages
inform An information message
warn A warning message
error An error message
( fatal --errno 2 A fatal error )

title Simple checks
check --level warn --message "No warning occured." return 0
check -l warn -m "A warning occured." return 1
check -l error -m "No error occured." return 0
check -l error -m "An error occured." return 1

title Check exit code
( check -l fatal -m "A fatal error occured in a sub-shell." return 1 )
check -m "Check if fatal error causes exit." test ${?} -eq 1
check -l error --errno 2 -m "Raise an error and override return code to 2." return 1
check echo '$?='${?}\; test ${?} -eq 2

title Query and reply
answer=$( ( sleep 1;echo yes ) | query Will say '"yes"' in 1 second. )
check -m 'Check if answer is "yes".' test "${answer}" = yes

title Confirm
echo | confirm --yes '"yes" is default'
check -m 'Check if reply is affirmative.' test ${?} -eq 0
echo foo | confirm --yes --assert 'Invalid value whith --assert'
check -m 'Check return code is 2.' test ${?} -eq 2
echo foo | confirm --yes 'Invalid value without --assert'
check -m 'Check return code is 0 (default for --yes)' test ${?} -eq 0
confirm --yes --loop 3 tries << EOF
foo
bar
no
foo
EOF
check -m 'Check if third reply is negative.' test ${?} -eq 1
