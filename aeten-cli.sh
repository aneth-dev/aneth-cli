#!/bin/sh

__colorize() {
	local color="${1}"; shift
	echo "$(test $(tput colors 2>/dev/null) -ge 8 && printf "\033[${color}${@}\033[0;0m" || echo "${@}")"
}

LEVEL_FATAL=0
LEVEL_ERROR=$((${LEVEL_FATAL}+1))
LEVEL_WARNING=$((${LEVEL_ERROR}+1))
LEVEL_INFORMATION=$((${LEVEL_WARNING}+1))
LEVEL_INFO=${LEVEL_INFORMATION}
LEVEL_DEBUG=$((${LEVEL_INFORMATION}+1))
LEVEL_TRACE=$((${LEVEL_DEBUG}+1))


: ${CONFIG_FILE=$(for prefix in /etc/ ~/. ~/.config/ ~/.etc/; do echo ${prefix}aeten-cli; done)}
for config_file in ${CONFIG_FILE}; do
	[ -f ${config_file} ] && . ${config_file}
done

: ${LEVEL=${LEVEL_INFO}}
: ${INFORMATION=INFO}
: ${WARNING=WARN}
: ${SUCCESS=OK}
: ${FAILURE=FAIL}
: ${DEBUG=DEBU}
: ${TRACE=TRAC}
: ${QUERY=WARN}
: ${ANSWERED=INFO}
: ${VERBOSE==>}
: ${OPEN_BRACKET=[ }
: ${CLOSE_BRACKET= ]}
: ${INVALID_REPLY_MESSAGE=%s: Invalid reply (%s was expected).}
: ${YES_DEFAULT='[Yes|no]:'}
: ${NO_DEFAULT='[yes|No]:'}
: ${YES_PATTERN='y|yes|Yes|YES'}
: ${NO_PATTERN='n|no|No|NO'}

__string_length() {
	printf "${@}"|wc -m
}

__add_padding() {
	local length
	local string
	local string_length
	local padding_left
	local padding_right
	length=${1}; shift
	string="${@}"
	string_length=$(__string_length "${string}")
	padding_left=$(( (${length}-${string_length}) / 2 ))
	padding_right=$(( ${padding_left} + (${length}-${string_length}) % 2 ))
	printf "%${padding_left}s%s%${padding_right}s" '' "${string}" ''
}

if [ 0 -eq ${TAG_LENGTH:-0} ]; then
	TAG_LENGTH=0
	for TAG in "${INFORMATION}" "${WARNING}" "${SUCCESS}" "${FAILURE}" "${QUERY}" "${ANSWERED}"; do
		[ ${#TAG} -gt ${TAG_LENGTH} ] && TAG_LENGTH=$(__string_length "${TAG}")
	done
	unset TAG
fi
EMPTY_TAG=$(__add_padding ${TAG_LENGTH} '')
TEXT_ALIGN="$(printf "%$(($(__string_length "${OPEN_BRACKET}${EMPTY_TAG}${CLOSE_BRACKET}") + 1))s" '')"

INFORMATION="$(__colorize '1;37m' "$(__add_padding ${TAG_LENGTH} "${INFORMATION}")")"
QUERY="$(__colorize '1;33m' "$(__add_padding ${TAG_LENGTH} "${QUERY}")")"
ANSWERED="$(__colorize '1;37m' "$(__add_padding ${TAG_LENGTH} "${ANSWERED}")")"
WARNING="$(__colorize '1;33m' "$(__add_padding ${TAG_LENGTH} "${WARNING}")")"
SUCCESS="$(__colorize '1;32m' "$(__add_padding ${TAG_LENGTH} "${SUCCESS}")")"
FAILURE="$(__colorize '1;31m' "$(__add_padding ${TAG_LENGTH} "${FAILURE}")")"
DEBUG="$(__colorize '1;34m' "$(__add_padding ${TAG_LENGTH} "${DEBUG}")")"
TRACE="$(__colorize '1;34m' "$(__add_padding ${TAG_LENGTH} "${TRACE}")")"
VERBOSE="$(__colorize '1;37m' "$(__add_padding ${TAG_LENGTH} "${VERBOSE}")")"
OPEN_BRACKET=$(__colorize '0;37m' "${OPEN_BRACKET}")
CLOSE_BRACKET=$(__colorize '0;37m' "${CLOSE_BRACKET}")
TITLE_COLOR='1;37m'
SAVE_CURSOR_POSITION='\033[s'
RESTORE_CURSOR_POSITION='\033[u'
MOVE_CURSOR_UP='\033[1A'
MOVE_CURSOR_DOWN='\033[1B'
CLEAR_LINE='\033[2K'

__ppid() {
	awk '{print $4}' /proc/${1}/stat 2>/dev/null
}

__out_fd() {
	local pid
	pid=${$}
	while [ ${pid} -ne 1 ]; do
		script=$(cat /proc/${pid}/cmdline | tr '\000' ' ' | awk '{print $2}')
		pid=$(__ppid ${pid})
		[ ${pid} -eq 1 ] && { pid=${$}; break; }
		[ -f "${script}" ] && [ $(basename "${script}") = query ] && { pid=$(__ppid ${pid}); break; }
	done
	echo /proc/${pid}/fd/${1}
}

OUTPUT=$(__out_fd 2)

__api() {
	sed --quiet --regexp-extended 's/(^[[:alnum:]][[:alnum:]_-]*)\s*\(\)\s*\{/\1/p' "${*}" 2>/dev/null
}

__is_api() {
	test 1 -eq $(__api "${1}"|grep -F "$(basename ${1})"|wc -l) 2>/dev/null
}

__tag() {
	local eol
	local restore
	local moveup
	local tag
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
	case "${1}" in
		info|inform) tag="${INFORMATION}";;
		success)     tag="${SUCCESS}";;
		warn)        tag="${WARNING}";;
		error)       tag="${FAILURE}";;
		fatal)       tag="${FAILURE}";;
		query)       tag="${QUERY}";;
		confirm)     tag="${ANSWERED}";;
		verbose)     tag="${VERBOSE}";;
		*)           tag="${1}";;
	esac
	printf "${moveup}\r${OPEN_BRACKET}%s${CLOSE_BRACKET}${restore}${eol}" "${tag}" >${OUTPUT}
}

__is_log_enable() {
	[ ${LEVEL} -ge $(__get_log_level ${1}) ] && echo true || echo false
}

__log() {
	local level
	local eol
	local save
	local message
	eol="\n"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-s) save=${SAVE_CURSOR_POSITION};;
			-n) eol="";;
			*) break;;
		esac
		shift
	done
	level="${1}"; shift
	message="${@}"
	printf "\r${CLEAR_LINE}${OPEN_BRACKET}%s${CLOSE_BRACKET} %s${save}${eol}" "${level}" "$message" >${OUTPUT}
}

title() {
	local mesage
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	message="${@}"
	echo "${TEXT_ALIGN}$(__colorize ${TITLE_COLOR} "${message}")" >${OUTPUT}
}

inform() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable info) && __log "${INFORMATION}" "${@}"
}

success() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable info) && __log "${SUCCESS}" "${@}"
}

warn() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable warn) && __log "${WARNING}" "${@}"
}

error() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable error) && __log "${FAILURE}" "${@}"
}

fatal() {
	local usage
	local errno
	usage="${FUNCNAME:-${0}} [--help|h] [--errno|-e <errno>] [--] <message>"
	errno=1

	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-e|--errno)   errno=${2}; shift ;;
			-h|--help)    echo "${usage}" >&2; exit 0 ;;
			--)           shift; break ;;
			-*)           echo "Usage: ${usage}" >&2; exit 1 ;;
			*)            break ;;
		esac
		shift
	done
	[ 0 -lt ${#} ] || { echo "Usage: ${usage}" >&2 ; exit 2; }
	$(__is_log_enable fatal) && __log "${FAILURE}" "${@}"
	exit ${errno}
}

debug() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable debug) && __log "${DEBUG}" "${@}"
}

trace() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable trace) && __log "${TRACE}" "${@}"
}

aeten_cli_get_log_level() {
	case "${LEVEL}" in
		${LEVEL_FATAL})       echo fatal;;
		${LEVEL_ERROR})       echo error;;
		${LEVEL_WARNING})     echo warn;;
		${LEVEL_INFORMATION}) echo info;;
		${LEVEL_DEBUG})       echo debug;;
		${LEVEL_TRACE})       echo trace;;
		*) echo "Usage: ${FUNCNAME:-${0}} fatal|error|warn|info|debug|trace" >&2 ; exit 1;;
	esac
}

__get_log_level() {
	case "${1}" in
		fatal)                   echo ${LEVEL_FATAL};;
		error)                   echo ${LEVEL_ERROR};;
		warn|warning)            echo ${LEVEL_WARNING};;
		info|inform|information) echo ${LEVEL_INFORMATION} ;;
		debug)                   echo ${LEVEL_DEBUG};;
		trace)                   echo ${LEVEL_TRACE};;
		*) echo "Usage: ${FUNCNAME:-${0}} fatal|error|warn|info|debug|trace" >&2 ; exit 1;;
	esac
}

aeten_cli_set_log_level() {
	LEVEL=$(__get_log_level ${1})
}

query() {
	local out
	local usage
	local out
	local script
	usage="${FUNCNAME:-${0}} [--help|-h] [--] <message>"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-h|--help)     echo "${usage}" >&2; exit 0 ;;
			--)            shift; break ;;
			-*)            echo "Usage:\n${usage}" >&2; exit 3 ;;
			*)             break ;;
		esac
		shift
	done
	[ 2 -eq $(basename ${OUTPUT}) ] && out=${OUTPUT} || out=$(__out_fd 2)
	__log -n -s "${QUERY}" "${*} " > ${out}
	read REPLY
	{ [ -t 0 ] && __tag -r -u "${ANSWERED}" || __tag -r "${ANSWERED}"; } >${out}
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
	local query_args
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
			-y|--yes)      expected=${YES_DEFAULT} ;;
			-n|--no)       expected=${NO_DEFAULT} ;;
			-a|--assert)   assert=1 ;;
			-l|--loop)     loop=1 ;;
			--yes-pattern) yes_pattern=${2}; shift ;;
			--no-pattern)  no_pattern=${2}; shift ;;
			-h|--help)     echo "${usage}" >&2; exit 0 ;;
			--)            shift; break ;;
			-*)            echo "Usage:\n${usage}" >&2; exit 3 ;;
			*)             break ;;
		esac
		shift
	done

	while true; do
		reply=$(query ${query_args} ${*} "${expected}")
		echo "${reply}" | grep --extended-regexp "${yes_pattern}|${no_pattern}" 2>&1 1>/dev/null && break
		if [ ${loop:-0} -eq 1 ]; then
			printf "${INVALID_REPLY_MESSAGE}\n" "${reply}" "[${yes_pattern}|${no_pattern}]" >${OUTPUT}
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
	local mode
	local mode_usage
	local usage
	local is_log_enable
	usage="${FUNCNAME:-${0}} [--quiet|-q] [--verbose|-v] [--level|-l warn|error|fatal] [--errno|-e <errno>] [--message|-m <message>] [--] <command>"
	mode_usage="--quiet and --verbose are incompatible options.\nUsage: ${usage}"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-m|--message) message=${2}; shift ;;
			-l|--level)   level=${2}; shift ;;
			-e|--errno)   errno=${2}; shift ;;
			-v|--verbose) [ -z ${mode:-} ] && mode=verbose || { echo "Usage: ${mode_usage}" >&2; exit 3; } ;;
			-q|--quiet)   [ -z ${mode:-} ] && mode=quiet   || { echo "Usage: ${mode_usage}" >&2; exit 3; } ;;
			-h|--help)    echo "${usage}" >&2; exit 0 ;;
			--)           shift; break ;;
			-*)           echo "Usage: ${usage}" >&2; exit 3 ;;
			*)            break ;;
		esac
		shift
	done
	unset mode_usage
	unset usage
	: ${level=fatal}
	is_log_enable=$(__is_log_enable ${level})
	: ${mode=${is_log_enable}}
	: ${message=${*}}
	case ${mode} in
		verbose) ${is_log_enable} && {
		         	__log -s "${VERBOSE}" "${message}"
		         	( eval "${*}" >&2 2>${OUTPUT} )
		         } || output=$(eval "${*}" 2>&1);;
		quiet)   output=$(eval "${*}" 2>&1);;
		*)       ${is_log_enable} && __log -s -n "${EMPTY_TAG}" "${message}"
		         output=$(eval "${*}" 2>&1);;
	esac
	[ 0 -eq ${?} ] && errno=0 || errno=${errno:-${?}}
	if [ 0 -eq ${errno} ] && ${is_log_enable}; then
		case ${mode} in
			verbose) success "${message}";;
			quiet)   ;;
			*)       __tag success;;
		esac
	elif ${is_log_enable}; then
		case ${mode} in
			verbose)${level} "${message}";;
			quiet)  __log -s "${VERBOSE}" "${message}"
			        printf "%s\n%s" "${*}" "${output}" >${OUTPUT}
			        ${level} "${message}";;
			*)      __tag verbose
			        printf "%s\n%s" "${*}" "${output}" >${OUTPUT}
			        ${level} "${message}";;
		esac
		[ 'fatal' = ${level} ] && exit ${errno}
	fi
	return ${errno}
}

if [ 0 -eq ${AETEN_CLI_INCLUDE=0} ] && [ -L "${0}" ] && __is_api "${0}"; then
	$(basename ${0}) "${@}"
elif [ 0 -eq ${AETEN_CLI_INCLUDE} ] && [ ! -L "${0}" ]; then
	cmd=${1}
	if [ 1 -eq $(__api "${0}"|grep -- "${cmd}"|wc -l) ]; then
		shift
		${cmd} "${@}"
	fi
fi
