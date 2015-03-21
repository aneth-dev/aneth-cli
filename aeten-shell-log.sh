#!/bin/sh

__colorize() {
	local color=$1
	shift
	echo $(test $(tput colors 2>/dev/null) -ge 8 && printf "\033[${color}${*}\033[0;0m" || echo "${*}")
}

SAVE_CURSOR_POSITION='\033[s'
RESTORE_CURSOR_POSITION='\033[u'
MOVE_CURSOR_UP='\033[1A'
MOVE_CURSOR_DOWN='\033[1B'
CLEAR_LINE='\033[2K'
TITLE_COLOR='1;37m'
INFO=$(__colorize '1;37m' INFO)
WARN=$(__colorize '1;33m' WARN)
PASS=$(__colorize '1;32m' PASS)
FAIL=$(__colorize '1;31m' FAIL)
YES_DEFAULT='[Yes|no]:'
NO_DEFAULT='[yes|No]:'
YES_PATTERN='y|yes|Yes|YES'
NO_PATTERN='n|no|No|NO'
INVALID_REPLY_MESSAGE="%s: Invalid reply, %s was expected."
ERROR=${FAIL}
OPEN_BRACKET=$(__colorize '0;37m' '[ ')
CLOSE_BRACKET=$(__colorize '0;37m' ' ]')
EMPTY_TAG=$(printf "%4s")

__api() {
	sed --quiet --regexp-extended 's/(^[[:alnum:]][[:alnum:]_-]*)\s*\(\)\s*\{/\1/p' "${*}"
}

__tag() {
	local eol
	local restore
	eol="\n"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-r) rastore=${RESTORE_CURSOR_POSITION};;
			-n) eol="" ;;
			*) break;;
		esac
		shift
	done
	printf "\r${OPEN_BRACKET}${1}${CLOSE_BRACKET}${restore}${eol}"
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
	__log "${INFO}" "${*}"
}

pass() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${PASS}" "${*}"
}

warn() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${WARN}" "${*}"
}

error() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${FAIL}" "${*}"
}

fatal() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	__log "${FAIL}" "${*}"
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
	__log -n -s "${WARN}" "${*} " > ${out}
	read REPLY
	[ -t 0 ] && printf "${MOVE_CURSOR_UP}" > ${out}
	__tag -r "${INFO}" > ${out}
	echo ${REPLY}
}

confirm() {
	local expected
	local yes_pattern
	local no_pattern
	local usage
	local assert
	local reply
	expected=${NO_DEFAULT}
	yes_pattern=${YES_PATTERN}
	no_pattern=${NO_PATTERN}
	assert=0
	usage="${FUNCNAME:-${0}} [--yes|-y] [--yes-pattern <pattern>] [--no-pattern <pattern>] [--] <message>
${FUNCNAME:-${0}} [--no|n] [--yes-pattern <pattern>] [--no-pattern <pattern>] [--] <message>"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			--yes|-y)      expected=${YES_DEFAULT} ;;
			--no|-n)       expected=${NO_DEFAULT} ;;
			--yes-pattern) yes_pattern=${2}; shift ;;
			--no-pattern)  no_pattern=${2}; shift ;;
			--assert)      assert=1 ;;
			--help|-h)     echo "${usage}" >&2; exit 0 ;;
			--)            shift; break ;;
			-*)            echo "Usage:\n${usage}" >&2; exit 1 ;;
			*)             break ;;
		esac
		shift
	done

	while true; do
		reply=$(query ${*} "${expected}")
		[ ${assert} -eq 0 ] || {
			echo "${reply}" | grep --extended-regexp "${yes_pattern}|${no_pattern}" 2>/dev/null 1>/dev/null
		} && break
	done
	[ -z "${reply}" ] && { [ ${expected} = ${YES_DEFAULT} ] && return 0 || return 1; }
	echo "${reply}" | grep --extended-regexp "${yes_pattern}" 2>&1 1>/dev/null && return 0
	echo "${reply}" | grep --extended-regexp "${no_pattern}" 2>&1 1>/dev/null && return 1

	printf "${INVALID_REPLY_MESSAGE}\n" "${reply}" "[${yes_pattern}|${no_pattern}]" >&2
	return 2
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
	[ 0 -eq "${errno}" ] && __tag "${PASS}" || case ${level} in
		warn) __tag "${WARN}" ;;
		error) __tag "${ERROR}"; echo "${*}"; echo "${output}"|sed '$,/^\s*$/d' ;;
		fatal) __tag "${FAIL}";  echo "${*}"; echo "${output}"|sed '$,/^\s*$/d'; exit ${errno} ;;
	esac
	return ${errno}
}

if [ 0 -eq ${SHELL_LOG_INCLUDE:=0} ] && [ -L "${0}" ] && [ 1 -eq $(__api "${0}"|grep "$(basename ${0})"|wc -l) ]; then
	$(basename ${0}) "${@}"
fi
