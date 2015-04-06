#!/bin/sed -f
s/^\(.*\)#.*$/\1/
/^\s*$/ d
/^.*\$$/ {
	:join
	$!N
	s/^\(.*\)\$\n\+/\1/
	t join
}
/^rule\s\+/ {
	N
	s/^rule\s\+\([[:alnum:]_-]\+\)\n/\1 = /
	s/${\?in}\?/$1/g
	s/${\?out}\?/$2/g
	s/\s\+description\s*=\s*\(.*\)$/ @@@check@@ -m "\1"/
	N
	s/${\?in}\?/$1/g
	s/${\?out}\?/$2/g
	/\s\+command\s*=/ {
		s/||\||\|&&\|>\|</'\0'/g
		s/\s\+command\s*=\s*\(.*\)/ \1/
	}
	/^.*\$$/ {
		:join
		$!N
		s/${\?in}\?/$1/g
		s/${\?out}\?/$2/g
		s/^\(.*\)\$\n\+/\1/
		t join
	}
}
/^build\s\+/ {
	s/^build\s\+\([[:alnum:]@\/_-]\+\):\s\+phony\(\s*||\s*\(.*\)\)\?/\n.PHONY: \1\n\1: \3/
	s/^build\s\+\([[:alnum:]@\/_-]\+\):\s\+\([[:alnum:]_-]\+\)\(\s\+\(.*\)\)/\n\1:\n\t$(call \2,\4,$@)/
	s/^build\s\+\([[:alnum:]@\/_-]\+\):\s\+\([[:alnum:]_-]\+\)/\n\1:\n\t$(call \2,$@)/
	s/^build\s\+/\n/
	
}
s/^default\(\s\+\)/\n.DEFAULT:\1/
