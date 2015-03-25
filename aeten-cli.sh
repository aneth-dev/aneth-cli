#!/bin/sh

__colorize() {
	local color=$1
	shift
	echo $(test $(tput colors 2>/dev/null) -ge 8 && printf "\033[${color}${*}\033[0;0m" || echo "${*}")
}

LEVEL_FATAL=0
LEVEL_ERROR=$((${LEVEL_FATAL}+1))
LEVEL_WARNING=$((${LEVEL_ERROR}+1))
LEVEL_INFORMATION=$((${LEVEL_WARNING}+1))
LEVEL_INFO=${LEVEL_INFORMATION}
LEVEL_DEBUG=$((${LEVEL_INFORMATION}+1))
LEVEL_TRACE=$((${LEVEL_DEBUG}+1))

[ -f /etc/aeten-cli ] && . /etc/aeten-cli
[ -f ~/.aeten-cli ] && . ~/.aeten-cli
[ -f ~/.config/aeten-cli ] && . ~/.config/aeten-cli
[ -f ~/.etc/aeten-cli ] && . ~/.etc/aeten-cli

: ${LEVEL=${LEVEL_INFO}}
: ${INFORMATION=INFO}
: ${WARNING=WARN}
: ${SUCCESS= OK }
: ${FAILURE=FAIL}
: ${DEBUG=DEBU}
: ${TRACE=TRAC}
: ${QUERY=WARN}
: ${ANSWERED=INFO}
: ${VERBOSE= => }
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
DEBUG=$(__colorize '1;34m' "${DEBUG}")
TRACE=$(__colorize '1;34m' "${TRACE}")
VERBOSE=$(__colorize '1;37m' "${VERBOSE}")
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
		info|inform) tag=${INFORMATION} ;;
		success)     tag=${SUCCESS};;
		warn)        tag=${WARNING};;
		error)       tag=${FAILURE};;
		fatal)       tag=${FAILURE};;
		query)       tag=${QUERY};;
		confirm)     tag=${ANSWERED};;
		verbose)     tag=${VERBOSE};;
		*)           tag=${1};;
	esac
	printf "${moveup}\r${OPEN_BRACKET}${tag}${CLOSE_BRACKET}${restore}${eol}" >${OUTPUT}
}

__is_log_enable() {
	[ ${LEVEL} -ge $(__get_log_level ${1}) ] && echo true || echo false
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
	printf "\r${CLEAR_LINE}${OPEN_BRACKET}${level}${CLOSE_BRACKET} ${*}${save}${eol}" >${OUTPUT}
}

title() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	echo $(__colorize ${TITLE_COLOR} "${*}") >${OUTPUT}
}

inform() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable info) && __log "${INFORMATION}" "${*}"
}

success() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable info) && __log "${SUCCESS}" "${*}"
}

warn() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable warn) && __log "${WARNING}" "${*}"
}

error() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable error) && __log "${FAILURE}" "${*}"
}

fatal() {
	local usage
	local errno
	usage="${FUNCNAME:-${0}} [--help|h] [--errno|-e <errno>] [--] <message>"
	errno=1

	while [ ${#} -ne 0 ]; do
		case "${1}" in
			--errno|-e)   errno=${2}; shift ;;
			--help|-h)    echo "${usage}" >&2; exit 0 ;;
			--)           shift; break ;;
			-*)           echo "Usage: ${usage}" >&2; exit 1 ;;
			*)            break ;;
		esac
		shift
	done
	[ 0 -lt ${#} ] || { echo "Usage: ${usage}" >&2 ; exit 2; }
	$(__is_log_enable fatal) && __log "${FAILURE}" "${*}"
	exit ${errno}
}

debug() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable debug) && __log "${DEBUG}" "${*}"
}

trace() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME:-${0}} <message>" >&2 ; exit 1; }
	$(__is_log_enable trace) && __log "${TRACE}" "${*}"
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
			--help|-h)     echo "${usage}" >&2; exit 0 ;;
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
	local usage
	local verbose
	local quiet
	local is_log_enable
	verbose=false
	quiet=false
	usage="${FUNCNAME:-${0}} [--quiet|-q] [--verbose|-v] [--level|-l warn|error|fatal] [--errno|-e <errno>] [--message|-m <message>] [--] <command>"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			--message|-m) message=${2}; shift ;;
			--level|-l)   level=${2}; shift ;;
			--errno|-e)   errno=${2}; shift ;;
			--verbose|-v) verbose=true ;;
			--quiet|-q)   quiet=true ;;
			--help|-h)    echo "${usage}" >&2; exit 0 ;;
			--)           shift; break ;;
			-*)           echo "Usage: ${usage}" >&2; exit 3 ;;
			*)            break ;;
		esac
		shift
	done
	${verbose} && ${quiet} && echo "--quiet and --verbose are incompatible options.\nUsage: ${usage}" >&2 && exit 3
	: ${level=fatal}
	: ${message=${*}}
	is_log_enable=$(__is_log_enable ${level})
	if $verbose; then
		if ${is_log_enable}; then
			${quiet} || __log -s "${VERBOSE}" "${message}"
			( eval "${*}" >&2 2>${OUTPUT} )
		else
			( eval "${*}" 2>&1 1>/dev/null )
		fi
	elif ${is_log_enable}; then
		${quiet} || __log -s -n "${EMPTY_TAG}" "${message}"
	fi
	output=$(eval "${*}" 2>&1)
	if [ 0 -eq ${?} ]; then
		errno=0
	else
		errno=${errno:-${?}}
	fi
	if [ 0 -eq ${errno} ]; then
		if ${verbose} || ${quiet}; then
			${quiet} || success "${message}"
		else
			${is_log_enable} && __tag success
		fi
	else
		if ${verbose} || ${quiet}; then
			${level} "${message}"
		elif ${is_log_enable}; then
			__tag ${level}
			printf "%s\n%s\n" "${*}" "${output}"|sed '$,/^\s*/d' >${OUTPUT}
			${level} "${message}"
		fi
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
