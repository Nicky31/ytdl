#!/bin/env bash

BASE_DIR=$(dirname $0)
YOUTUBE_REGEX="youtube.[a-z]{1,5}/watch"

_tabs_autocomplete()
{
  IFS=$'\n' tabs=($(python $BASE_DIR/list-fftabs.py | grep -E "$YOUTUBE_REGEX" | jq -r .title))
  local cur=${COMP_WORDS[COMP_CWORD]}

  COMPREPLY=()
  for tab in ${tabs[@]} ; do
    COMPREPLY+=( `compgen -W "${tab}" -- $cur` )
  done
}

complete -F _tabs_autocomplete ytdl

