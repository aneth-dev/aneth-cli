#!/bin/bash

__api() {
	sed --quiet --regexp-extended 's/^([[:alpha:]][[:alnum:]_-]*)\(\)\s*\{/\1/p' "${0}" 2>/dev/null
}

__is_api() {
	__api|grep "^${1}$" >&/dev/null
}

__help() {
	echo "${@}" >&2
	exit 0
}

__usage() {
	echo "Usage:
$(echo "${@}"|sed 's/^/\t/')" >&2
	exit 1
}


add-prefix() {
	local prefix=${1}; shift
	{
		while [ ${#} -ne 0 ]; do
			echo "${1}"|sed "s@.*@${prefix}\\0@"
			shift
		done
	} | paste -sd' '
}

target() {
	local target
	local depends
	local usage="${0} [-d|--depends <depedency>] <targets-list>"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-d|--depends) depends="${depends} ${2}"; shift;;
			-h|--help)    __help "$1 ${usage}"; shift ;;
			--)           shift; break;;
			-*)           __usage "$1 ${usage}";;
			*)            break;;
		esac
		shift
	done
	{
		for target in "${@}"; do
			echo "build ${target}: ${depends}"
		done
	} | sed -e 's/$/\\/' -e '$s/\\$//'
}

generate() {
	local usage="${0} [-b|--builder <ninja|make>] <template>
${0} [$(__api|paste -sd\|)] --help"
	local template=template.ninja
	local builder
	local extension
	local dict
	while [ ${#} -ne 0 ]; do
		case "${1}" in
			-t|--template) template=${2}; shift ;;
			-h|--help)    __help "${usage}"; shift ;;
			*)            __usage "${usage}";;
		esac
	done
	for extension in ninja make; do
		[ $(basename ${template} .${extension}) = $(basename ${template}) ] || { builder=${extension}; break; }
	done
	case "${builder}" in
		ninja);;
		*) __usage "Invalid builder ${builder}\n${usage}";;
	esac
	eval sed $(cat /dev/stdin|sed -e ':a;N;$!ba;s/\\\n/\\x00/g'|sed --regexp-extended -e 's,^([[:alpha:]][[:alnum:]_-]*)\s*=\s*(.*), -e "s@\\@\\@\1\\@\\@@\2@g",'|sed ':a;N;$!ba;s/\n//g') ${template} | sed 's/\x00/\n/g' > $(dirname ${template})/build.${extension}
}

if __is_api "${1}"; then
	cmd=${1}
	shift
	${cmd} "${@}"
else
	generate "${@}"
fi

