#!/bin/env bash

BASE_DIR=$(dirname $0)
_tabs_autocomplete()
{
  IFS=$'\n' tabs=($(python $BASE_DIR/list-fftabs.py | grep -E "youtube.[a-z]{1,5}/watch" | jq -r .title))
  local cur=${COMP_WORDS[COMP_CWORD]}

  COMPREPLY=()
  for tab in ${tabs[@]} ; do
    COMPREPLY+=( `compgen -W "${tab}" -- $cur` )
  done
}

complete -F _tabs_autocomplete ytdl

