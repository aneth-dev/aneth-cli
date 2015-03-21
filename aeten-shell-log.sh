#!/bin/sh

__colorize() {
	local color=$1
	shift
	echo $(test $(tput colors 2>/dev/null) -ge 8 && printf "\033[${color}${*}\033[0;0m" || echo "${*}")
}

[ -f /etc/aeten-shell-log ] && . /etc/aeten-shell-log
[ -f ~/.aeten-shell-log ] && . ~/.aeten-shell-log
[ -f ~/.config/aeten-shell-log ] && . ~/.config/aeten-shell-log
[ -f ~/.etc/aeten-shell-log ] && . ~/.etc/aeten-shell-log

: ${INFORMATION=INFO}
: ${WARNING=WARN}
: ${SUCCESS=PASS}
: ${FAILURE=FAIL}
: ${QUERY=WARN}
: ${ANSWERED=INFO}
: ${OPEN_BRACKET=[ }
: ${CLOSE_BRACKET= ]}
: ${INVALID_REPLY_MESSAGE=%s: Invalid reply (%s was expected).}
: ${YES_DEFAULT='[Yes|no]:'}
: ${NO_DEFAULT='[yes|No]:'}
: ${YES_PATTERN='y|yes|Yes|YES'}
: ${NO_PATTERN='n|no|No|NO'}
if [ 0 -eq ${TAG_LENGTH:-0} ]; then
	TAG_LENGTH=0
	for TAG in "${INFORMATION}" "${WARNING}" "${SUCCESS}" "${FAILURE}" "${QUERY}" "${ANSWERED}"; do
		[ ${#TAG} -gt ${TAG_LENGTH} ] && TAG_LENGTH=${#TAG}
	done
	unset TAG
fi
EMPTY_TAG=$(printf "%${TAG_LENGTH}s")
unset TAG_LENGTH
INFORMATION=$(__colorize '1;37m' "${INFORMATION}")
QUERY=$(__colorize '1;33m' "${QUERY}")
ANSWERED=$(__colorize '1;37m' "${ANSWERED}")
WARNING=$(__colorize '1;33m' "${WARNING}")
SUCCESS=$(__colorize '1;32m' "${SUCCESS}")
FAILURE=$(__colorize '1;31m' "${FAILURE}")
OPEN_BRACKET=$(__colorize '0;37m' "${OPEN_BRACKET}")
CLOSE_BRACKET=$(__colorize '0;37m' "${CLOSE_BRACKET}")
TITLE_COLOR='1;37m'
SAVE_CURSOR_POSITION='\033[s'
RESTORE_CURSOR_POSITION='\033[u'
MOVE_CURSOR_UP='\033[1A'
MOVE_CURSOR_DOWN='\033[1B'
CLEAR_LINE='\033[2K'

__api() {
	sed --quiet --regexp-extended 's/(^[[:alnum:]][[:alnum:]_-]*)\s*\(\)\s*\{/\1/p' "${*}"
}

__tag() {
	local eol
	local restore
	local moveup
	eol="\n"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-r) restore=${RESTORE_CURSOR_POSITION} ;;
			-u) moveup=${MOVE_CURSOR_UP} ;;
			-n) eol="" ;;
			*) break;;
		esac
		shift
	done
	printf "${moveup}\r${OPEN_BRACKET}${1}${CLOSE_BRACKET}${restore}${eol}"
}

__log() {
	local level
	local eol
	local save
	eol="\n"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-s) save=${SAVE_CURSOR_POSITION};;
			-n) eol="";;
			*) break;;
		esac
		shift
	done
	level=${1}; shift
	printf "\r${OPEN_BRACKET}${level}${CLOSE_BRACKET} ${*}${save}${eol}"
}

__ppid() {
	awk '{print $4}' /proc/${1}/stat
}

title() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	echo $(__colorize ${TITLE_COLOR} "${*}")
}

inform() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${INFORMATION}" "${*}"
}

success() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${SUCCESS}" "${*}"
}

warn() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${WARNING}" "${*}"
}

error() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${FAILURE}" "${*}"
}

fatal() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${FAILURE}" "${*}"
	exit 1
}

query() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	local pid
	local out
	local script
	pid=${$}
	while [ ${pid} -ne 1 ]; do
		script=$(cat /proc/${pid}/cmdline | tr '\000' ' ' | awk '{print $2}')
		pid=$(__ppid ${pid})
		[ ${pid} -eq 1 ] && { pid=${$}; break; }
		[ -f "${script}" ] && [ $(basename "${script}") = query ] && { pid=$(__ppid ${pid}); break; }
	done
	out=/proc/${pid}/fd/1
	__log -n -s "${QUERY}" "${*} " > ${out}
	read REPLY
	{ [ -t 0 ] && __tag -r -u "${ANSWERED}" || __tag -r "${ANSWERED}"; } > ${out}
	echo ${REPLY}
}

confirm() {
	local expected
	local yes_pattern
	local no_pattern
	local usage
	local assert
	local loop
	local reply
	expected=${NO_DEFAULT}
	yes_pattern=${YES_PATTERN}
	no_pattern=${NO_PATTERN}
	assert=0
	usage="${FUNCNAME:-${0}} [--assert|-a] [--yes-pattern <pattern>] [--no-pattern <pattern>] [--] <message>
${FUNCNAME:-${0}} [--assert|-a] [--yes-pattern <pattern>] [--no-pattern <pattern>] [--] <message>
${FUNCNAME:-${0}} [--yes|y] [--loop|-l] [--yes-pattern <pattern>] [--no-pattern <pattern>] [--] <message>
${FUNCNAME:-${0}} [--no|n] [--loop|-l] [--yes-pattern <pattern>] [--no-pattern <pattern>] [--] <message>
\t-y, yes
\t\tPositive reply is default.
\t-n, no
\t\tNegative reply is default.
\t-a, --assert
\t\tReturn code is 2 if reply does not matches patterns.
\t--yes-pattern
\t\tThe extended-regex (see grep) for positive answer.
\t--no-pattern
\t\tThe extended-regex (see grep) for negative answer.
"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			--yes|-y)      expected=${YES_DEFAULT} ;;
			--no|-n)       expected=${NO_DEFAULT} ;;
			--assert|-a)   assert=1 ;;
			--loop|-l)     loop=1 ;;
			--yes-pattern) yes_pattern=${2}; shift ;;
			--no-pattern)  no_pattern=${2}; shift ;;
			--help|-h)     echo "${usage}" >&2; exit 0 ;;
			--)            shift; break ;;
			-*)            echo "Usage:\n${usage}" >&2; exit 3 ;;
			*)             break ;;
		esac
		shift
	done

	while true; do
		reply=$(query ${*} "${expected}")
		echo "${reply}" | grep --extended-regexp "${yes_pattern}|${no_pattern}" 2>/dev/null 1>/dev/null && break
		if [ ${loop:-0} -eq 1 ]; then
			printf "${INVALID_REPLY_MESSAGE}\n" "${reply}" "[${yes_pattern}|${no_pattern}]" >&2
		else
			break
		fi
	done
	[ -z "${reply}" ] && { [ ${expected} = ${YES_DEFAULT} ] && return 0 || return 1; }
	echo "${reply}" | grep --extended-regexp "${yes_pattern}" 2>&1 1>/dev/null && return 0
	echo "${reply}" | grep --extended-regexp "${no_pattern}" 2>&1 1>/dev/null && return 1
	[ ${assert:-0} -eq 0 ] && { [ ${expected} = ${YES_DEFAULT} ] && return 0 || return 1; } || return 2
}

check() {
	local level
	local message
	local errno
	local output
	local usage
	usage="${FUNCNAME:-${0}} [--level|-l warn|error|fatal] [--errno|-e <errno>] [--message|-m <message>] [--] <command>"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			--message|-m) message=${2}; shift ;;
			--level|-l)   level=${2}; shift ;;
			--errno|-e)   errno=${2}; shift ;;
			--help|-h)    echo "${usage}"; exit 0 ;;
			--)           shift; break ;;
			-*)           echo "Usage: ${usage}" >&2; exit 3 ;;
			*)            break ;;
		esac
		shift
	done
	: ${level=fatal}
	: ${message=${*}}
	__log -s -n "${EMPTY_TAG}" "${message}"
	output=$(eval "${*}" 2>&1)
	if [ 0 -eq ${?} ]; then
		errno=0
	else
		errno=${errno:-${?}}
	fi
	[ 0 -eq "${errno}" ] && __tag "${SUCCESS}" || case ${level} in
		warn) __tag "${WARNING}" ;;
		error) __tag "${FAILURE}"; echo "${*}"; echo "${output}"|sed '$,/^\s*$/d' ;;
		fatal) __tag "${FAILURE}"; echo "${*}"; echo "${output}"|sed '$,/^\s*$/d'; exit ${errno} ;;
	esac
	return ${errno}
}

if [ 0 -eq ${SHELL_LOG_INCLUDE:=0} ] && [ -L "${0}" ] && [ 1 -eq $(__api "${0}"|grep "$(basename ${0})"|wc -l) ]; then
	$(basename ${0}) "${@}"
fi
