#!/bin/sh

__aeten_cli_colorize() {
	local color="${1}"; shift
	echo "$(test $(tput colors 2>/dev/null) -ge 8 && printf "\033[${color}${@}\033[0;0m" || echo "${@}")"
}

AETEN_CLI_LEVEL_FATAL=0
AETEN_CLI_LEVEL_ERROR=$((${AETEN_CLI_LEVEL_FATAL}+1))
AETEN_CLI_LEVEL_WARNING=$((${AETEN_CLI_LEVEL_ERROR}+1))
AETEN_CLI_LEVEL_INFORMATION=$((${AETEN_CLI_LEVEL_WARNING}+1))
AETEN_CLI_LEVEL_INFO=${AETEN_CLI_LEVEL_INFORMATION}
AETEN_CLI_LEVEL_DEBUG=$((${AETEN_CLI_LEVEL_INFORMATION}+1))
AETEN_CLI_LEVEL_TRACE=$((${AETEN_CLI_LEVEL_DEBUG}+1))


: ${AETEN_CLI_CONFIG_FILE=$(for prefix in /etc/ ~/. ~/.config/ ~/.etc/; do echo ${prefix}aeten-cli; done)}
for config_file in ${AETEN_CLI_CONFIG_FILE}; do
	[ -f ${config_file} ] && . ${config_file}
done

: ${AETEN_CLI_LEVEL=${AETEN_CLI_LEVEL_INFO}}
: ${AETEN_CLI_INFORMATION=INFO}
: ${AETEN_CLI_WARNING=WARN}
: ${AETEN_CLI_SUCCESS=OK}
: ${AETEN_CLI_FAILURE=FAIL}
: ${AETEN_CLI_DEBUG=DEBU}
: ${AETEN_CLI_TRACE=TRAC}
: ${AETEN_CLI_QUERY=WARN}
: ${AETEN_CLI_ANSWERED=INFO}
: ${AETEN_CLI_VERBOSE==>}
: ${AETEN_CLI_OPEN_BRACKET=[ }
: ${AETEN_CLI_CLOSE_BRACKET= ]}
: ${AETEN_CLI_INVALID_REPLY_MESSAGE=%s: Invalid reply (%s was expected).}
: ${AETEN_CLI_YES_DEFAULT='[Yes|no]:'}
: ${AETEN_CLI_NO_DEFAULT='[yes|No]:'}
: ${AETEN_CLI_YES_PATTERN='y|yes|Yes|YES'}
: ${AETEN_CLI_NO_PATTERN='n|no|No|NO'}

__aeten_cli_string_length() {
	printf "${@}"|wc -m
}

__aeten_cli_add_padding() {
	local length
	local string
	local string_length
	local padding_left
	local padding_right
	length=${1}; shift
	string="${@}"
	string_length=$(__aeten_cli_string_length "${string}")
	padding_left=$(( (${length}-${string_length}) / 2 ))
	padding_right=$(( ${padding_left} + (${length}-${string_length}) % 2 ))
	printf "%${padding_left}s%s%${padding_right}s" '' "${string}" ''
}

if [ 0 -eq ${AETEN_CLI_TAG_LENGTH:-0} ]; then
	AETEN_CLI_TAG_LENGTH=0
	for AETEN_CLI_TAG in "${AETEN_CLI_INFORMATION}" "${AETEN_CLI_WARNING}" "${AETEN_CLI_SUCCESS}" "${AETEN_CLI_FAILURE}" "${AETEN_CLI_QUERY}" "${AETEN_CLI_ANSWERED}"; do
		[ ${#AETEN_CLI_TAG} -gt ${AETEN_CLI_TAG_LENGTH} ] && AETEN_CLI_TAG_LENGTH=$(__aeten_cli_string_length "${AETEN_CLI_TAG}")
	done
	unset AETEN_CLI_TAG
fi
AETEN_CLI_EMPTY_TAG=$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} '')
AETEN_CLI_TEXT_ALIGN="$(printf "%$(($(__aeten_cli_string_length "${AETEN_CLI_OPEN_BRACKET}${AETEN_CLI_EMPTY_TAG}${AETEN_CLI_CLOSE_BRACKET}") + 1))s" '')"

AETEN_CLI_INFORMATION="$(__aeten_cli_colorize '1;37m' "$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} "${AETEN_CLI_INFORMATION}")")"
AETEN_CLI_QUERY="$(__aeten_cli_colorize '1;33m' "$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} "${AETEN_CLI_QUERY}")")"
AETEN_CLI_ANSWERED="$(__aeten_cli_colorize '1;37m' "$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} "${AETEN_CLI_ANSWERED}")")"
AETEN_CLI_WARNING="$(__aeten_cli_colorize '1;33m' "$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} "${AETEN_CLI_WARNING}")")"
AETEN_CLI_SUCCESS="$(__aeten_cli_colorize '1;32m' "$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} "${AETEN_CLI_SUCCESS}")")"
AETEN_CLI_FAILURE="$(__aeten_cli_colorize '1;31m' "$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} "${AETEN_CLI_FAILURE}")")"
AETEN_CLI_DEBUG="$(__aeten_cli_colorize '1;34m' "$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} "${AETEN_CLI_DEBUG}")")"
AETEN_CLI_TRACE="$(__aeten_cli_colorize '1;34m' "$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} "${AETEN_CLI_TRACE}")")"
AETEN_CLI_VERBOSE="$(__aeten_cli_colorize '1;37m' "$(__aeten_cli_add_padding ${AETEN_CLI_TAG_LENGTH} "${AETEN_CLI_VERBOSE}")")"
AETEN_CLI_OPEN_BRACKET=$(__aeten_cli_colorize '0;37m' "${AETEN_CLI_OPEN_BRACKET}")
AETEN_CLI_CLOSE_BRACKET=$(__aeten_cli_colorize '0;37m' "${AETEN_CLI_CLOSE_BRACKET}")
AETEN_CLI_TITLE_COLOR='1;37m'
AETEN_CLI_SAVE_CURSOR_POSITION='\033[s'
AETEN_CLI_RESTORE_CURSOR_POSITION='\033[u'
AETEN_CLI_MOVE_CURSOR_UP='\033[1A'
AETEN_CLI_MOVE_CURSOR_DOWN='\033[1B'
AETEN_CLI_CLEAR_LINE='\033[2K'

__aeten_cli_ppid() {
	awk '{print $4}' /proc/${1}/stat 2>/dev/null
}

__aeten_cli_out_fd() {
	local script
	local pid
	pid=${$}
	while [ ${pid} -ne 1 ]; do
		script=$(cat /proc/${pid}/cmdline | tr '\000' ' ' | awk '{print $2}')
		pid=$(__aeten_cli_ppid ${pid})
		[ ${pid} -eq 1 ] && { pid=${$}; break; }
		[ -f "${script}" ] && [ $(basename "${script}") = query ] && { pid=$(__aeten_cli_ppid ${pid}); break; }
	done
	echo /proc/${pid}/fd/${1}
}

AETEN_CLI_OUTPUT=$(__aeten_cli_out_fd 2)

__aeten_cli_api() {
	sed --quiet --regexp-extended 's/(^[[:alnum:]][[:alnum:]_-]*)\s*\(\)\s*\{/\1/p' "${*}" 2>/dev/null
}

__aeten_cli_is_api() {
	test 1 -eq $(__aeten_cli_api "${1}"|grep -F "$(basename ${1})"|wc -l) 2>/dev/null
}

__aeten_cli_tag() {
	local eol
	local restore
	local moveup
	local tag
	eol="\n"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-r) restore=${AETEN_CLI_RESTORE_CURSOR_POSITION};;
			-u) moveup=${AETEN_CLI_MOVE_CURSOR_UP};;
			-n) eol="" ;;
			*) break;;
		esac
		shift
	done
	case "${1}" in
		info|inform) tag="${AETEN_CLI_INFORMATION}";;
		success)     tag="${AETEN_CLI_SUCCESS}";;
		warn)        tag="${AETEN_CLI_WARNING}";;
		error)       tag="${AETEN_CLI_FAILURE}";;
		fatal)       tag="${AETEN_CLI_FAILURE}";;
		query)       tag="${AETEN_CLI_QUERY}";;
		confirm)     tag="${AETEN_CLI_ANSWERED}";;
		verbose)     tag="${AETEN_CLI_VERBOSE}";;
		*)           tag="${1}";;
	esac
	printf "${moveup}\r${AETEN_CLI_OPEN_BRACKET}%s${AETEN_CLI_CLOSE_BRACKET}${restore}${eol}" "${tag}" >${AETEN_CLI_OUTPUT}
}

__aeten_cli_is_log_enable() {
	[ ${AETEN_CLI_LEVEL} -ge $(__aeten_cli_get_log_level ${1}) ] && echo true || echo false
}

__aeten_cli_log() {
	local level
	local eol
	local save
	local message
	eol="\n"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-s) save=${AETEN_CLI_SAVE_CURSOR_POSITION};;
			-n) eol="";;
			*) break;;
		esac
		shift
	done
	level="${1}"; shift
	message="${@}"
	printf "\r${AETEN_CLI_CLEAR_LINE}${AETEN_CLI_OPEN_BRACKET}%s${AETEN_CLI_CLOSE_BRACKET} %s${save}${eol}" "${level}" "$message" >${AETEN_CLI_OUTPUT}
}

title() {
	local mesage
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	message="${@}"
	echo "${AETEN_CLI_TEXT_ALIGN}$(__aeten_cli_colorize ${AETEN_CLI_TITLE_COLOR} "${message}")" >${AETEN_CLI_OUTPUT}
}

inform() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__aeten_cli_is_log_enable info) && __aeten_cli_log "${AETEN_CLI_INFORMATION}" "${@}"
}

success() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__aeten_cli_is_log_enable info) && __aeten_cli_log "${AETEN_CLI_SUCCESS}" "${@}"
}

warn() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__aeten_cli_is_log_enable warn) && __aeten_cli_log "${AETEN_CLI_WARNING}" "${@}"
}

error() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__aeten_cli_is_log_enable error) && __aeten_cli_log "${AETEN_CLI_FAILURE}" "${@}"
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
	$(__aeten_cli_is_log_enable fatal) && __aeten_cli_log "${AETEN_CLI_FAILURE}" "${@}"
	exit ${errno}
}

debug() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	echo $(__aeten_cli_is_log_enable debug)
	$(__aeten_cli_is_log_enable debug) && __aeten_cli_log "${AETEN_CLI_DEBUG}" "${@}"
}

trace() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__aeten_cli_is_log_enable trace) && __aeten_cli_log "${AETEN_CLI_TRACE}" "${@}"
}

aeten_cli_get_log_level() {
	case "${AETEN_CLI_LEVEL}" in
		${AETEN_CLI_LEVEL_FATAL})       echo fatal;;
		${AETEN_CLI_LEVEL_ERROR})       echo error;;
		${AETEN_CLI_LEVEL_WARNING})     echo warn;;
		${AETEN_CLI_LEVEL_INFORMATION}) echo info;;
		${AETEN_CLI_LEVEL_DEBUG})       echo debug;;
		${AETEN_CLI_LEVEL_TRACE})       echo trace;;
		*) echo "Usage: ${FUNCNAME:-${0}} fatal|error|warn|info|debug|trace" >&2 ; exit 1;;
	esac
}

__aeten_cli_get_log_level() {
	case "${1}" in
		fatal)                   echo ${AETEN_CLI_LEVEL_FATAL};;
		error)                   echo ${AETEN_CLI_LEVEL_ERROR};;
		warn|warning)            echo ${AETEN_CLI_LEVEL_WARNING};;
		info|inform|information) echo ${AETEN_CLI_LEVEL_INFORMATION} ;;
		debug)                   echo ${AETEN_CLI_LEVEL_DEBUG};;
		trace)                   echo ${AETEN_CLI_LEVEL_TRACE};;
		*) echo "Usage: ${FUNCNAME:-${0}} fatal|error|warn|info|debug|trace" >&2 ; exit 1;;
	esac
}

aeten_cli_set_log_level() {
	AETEN_CLI_LEVEL=$(__aeten_cli_get_log_level ${1})
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
	[ 2 -eq $(basename ${AETEN_CLI_OUTPUT}) ] && out=${AETEN_CLI_OUTPUT} || out=$(__aeten_cli_out_fd 2)
	__aeten_cli_log -n -s "${AETEN_CLI_QUERY}" "${*} " > ${out}
	read REPLY
	{ [ -t 0 ] && __aeten_cli_tag -r -u "${AETEN_CLI_ANSWERED}" || __aeten_cli_tag -r "${AETEN_CLI_ANSWERED}"; } >${out}
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
	expected=${AETEN_CLI_NO_DEFAULT}
	yes_pattern=${AETEN_CLI_YES_PATTERN}
	no_pattern=${AETEN_CLI_NO_PATTERN}
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
			-y|--yes)      expected=${AETEN_CLI_YES_DEFAULT} ;;
			-n|--no)       expected=${AETEN_CLI_NO_DEFAULT} ;;
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
			printf "${AETEN_CLI_INVALID_REPLY_MESSAGE}\n" "${reply}" "[${yes_pattern}|${no_pattern}]" >${AETEN_CLI_OUTPUT}
		else
			break
		fi
	done
	[ -z "${reply}" ] && { [ ${expected} = ${AETEN_CLI_YES_DEFAULT} ] && return 0 || return 1; }
	echo "${reply}" | grep --extended-regexp "${yes_pattern}" 2>&1 1>/dev/null && return 0
	echo "${reply}" | grep --extended-regexp "${no_pattern}" 2>&1 1>/dev/null && return 1
	[ ${assert:-0} -eq 0 ] && { [ ${expected} = ${AETEN_CLI_YES_DEFAULT} ] && return 0 || return 1; } || return 2
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
	is_log_enable=$(__aeten_cli_is_log_enable ${level})
	: ${mode=${is_log_enable}}
	: ${message="${@}"}
	case ${mode} in
		verbose) ${is_log_enable} && {
		         	__aeten_cli_log -s "${AETEN_CLI_VERBOSE}" "${message}"
		         	( eval "${@}" >&2 2>${AETEN_CLI_OUTPUT} )
		         } || output=$(eval "${@}" 2>&1);;
		quiet)   output=$(eval "${@}" 2>&1);;
		*)       ${is_log_enable} && __aeten_cli_log -s -n "${AETEN_CLI_EMPTY_TAG}" "${message}"
		         output=$(eval "${@}" 2>&1);;
	esac
	[ 0 -eq ${?} ] && errno=0 || errno=${errno:-${?}}
	if [ 0 -eq ${errno} ] && ${is_log_enable}; then
		case ${mode} in
			verbose) success "${message}";;
			quiet)   ;;
			*)       __aeten_cli_tag success;;
		esac
	elif ${is_log_enable}; then
		case ${mode} in
			verbose)${level} "${message}";;
			quiet)  __aeten_cli_log -s "${AETEN_CLI_VERBOSE}" "${message}"
			        printf "%s\n%s" "${*}" "${output}" >${AETEN_CLI_OUTPUT}
			        ${level} "${message}";;
			*)      __aeten_cli_tag verbose
			        printf "%s\n%s" "${*}" "${output}" >${AETEN_CLI_OUTPUT}
			        ${level} "${message}";;
		esac
		[ 'fatal' = ${level} ] && exit ${errno}
	fi
	return ${errno}
}

if [ 0 -eq ${AETEN_CLI_INCLUDE=0} ] && [ -L "${0}" ] && __aeten_cli_is_api "${0}"; then
	$(basename ${0}) "${@}"
elif [ 0 -eq ${AETEN_CLI_INCLUDE} ] && [ ! -L "${0}" ]; then
	cmd=${1}
	if [ 1 -eq $(__aeten_cli_api "${0}"|grep -- "${cmd}"|wc -l) ]; then
		shift
		${cmd} "${@}"
	fi
fi
