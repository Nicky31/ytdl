# requires youtube-dl, jq, mid3v2
shopt -s nocasematch # case insensitive comparisons
shopt -s globstar # recursive ** globbin 
SAVE_DIRECTORY=${SAVE_DIRECTORY:-"/home/martin/Medias/Music/tri"}
LIST_FFTABS_SCRIPT=$HOME/bin/ytdl-cli/list-fftabs.py
LAST_TAB_FILE=/tmp/ff_last_tab
NOTIFY_SEND_WHEN_DMENU_TERM="dumb"
YOUTUBE_REGEX="youtube.[a-z]{1,5}/watch"
YTDL_HISTORY_DIR=${YTDL_HISTORY_DIR:-"/home/martin/Medias/Music/tri/logs"}

function usage() {
    echo Firefox tab usage : ytdl ff [SEARCH_TITLE] [ID3_OPTS]
    echo Single download usage : ytdl YOUTUBE_URL [ID3_OPTS] 
    echo Multi download usage : ytdl session [SAVE_DIRECTORY]
    echo ID3 tags editor usage : ytdl tags MP3_FILES    
}

function ytlog() {
    echo "${@}"
    if [[ $(command -v notify-send) ]] && [[ "$TERM" == "$NOTIFY_SEND_WHEN_DMENU_TERM" ]] ; then 
        notify-send --urgency=low -t 4000 "ytdl-ff" "${@}"
    fi    
}

if [[ -z $1 ]] ;
then
    echo Missing first parameter
    usage
    exit 1
fi


# @brief: Given filename + ID3 tag options, return output directory
# @arg1:  filename
# @args:  genres options
declare -A level_dirs=(
    ["lvl=1"]="1 - Relaxing"
    ["lvl=2"]="2 - CalmBackground"
    ["lvl=3"]="3 - RythmicBackground"
    ["lvl=4"]="4 - Dancing"
    ["lvl=5"]="5 - Tawa"
)
declare -A genre_dirs=(
    ["Techno"]="Techno"
    ["Techno Mélodique"]="Melodic Techno"
    ["Oldschool House"]="Oldschool House"
)
function print_out_dir() {
    local filename=$1
    shift
    local out_dir="$SAVE_DIRECTORY"

    # energy subdirectory
    local level_tag=$(printf "%s\n" "${@}" | grep "lvl=[0-9]")
    if [[ -n "$level_tag" ]] ; then 
        local level_dir="${level_dirs[$level_tag]}"
        if [[ -n "$level_dir" ]] && [[ -d "$out_dir/$level_dir" ]] ; then
            out_dir="$out_dir/$level_dir"            
        fi
    fi

    # genre subdirectory:  take the more specific (=longest) genre as directory
    local genre_dir="."
    for genre in "${!genre_dirs[@]}" ; do
        local cur_dir="${genre_dirs[$genre]}"
        if [[ "${*}" == *"$genre"* ]] && [[ -d "$out_dir/$cur_dir" ]]; then
            if [[ -z "$genre_dir" ]] || [[ ${#cur_dir} -gt ${#genre_dir} ]] ; then
                genre_dir="$cur_dir"
            fi
        fi
    done

    echo "$out_dir/$genre_dir/$filename"
}

# @brief: Download youtube MP3
# When artist or track is missing from downloaded ID3 tags, they are automatically retrieved from filename
# @arg1:  URL
# @args:  Refer to edit_id3tags args
function download() {
    local url=$1
    shift
    local meta
    local filename

    echo "Downloading $url ..."
    # Download MP3 & retrieve output filename
    meta=$(youtube-dl -x --audio-format mp3 --audio-quality 320K --no-playlist \
        --add-metadata  -o "%(title)s.%(ext)s" --print-json $url)
    if [[ $? -ne 0 ]] ;
    then
        ytlog "youtube-dl could not download '$url'"
        return 1
    fi
    youtube_channel=$(echo "$meta" | jq -r .uploader)
    filename=$(echo "$meta" | jq -r ._filename)
    filename=${filename/webm/mp3}

    # Filter out noisy words
    local renamed=${filename/\(Official Video\)}
    renamed=${renamed/\(Original mix\)}
    renamed=${renamed/.mp3} # remove extension in order to clean trailing whitespaces
    renamed=$(echo "$renamed" | sed -e 's/[[:space:]]*$//') # remove trailing whitespacess
    renamed=$renamed.mp3 # Add .mp3 extension
    mv "$filename" "$renamed" 2> /dev/null
    echo "Downloaded '$renamed'."
    filename=$renamed

    # Read defined artist / track
    artist=$(mid3v2 "$filename" | grep TPE1 | cut -d'=' -f2)
    track=$(mid3v2 "$filename" | grep TIT2 | cut -d'=' -f2)

    # If ID3 artist matches with youtube channel & is not indicated in filename : rename
    if [[ $youtube_channel == *$artist* ]] && [[ $filename != *"$artist"* ]] ; then
        renamed="$artist - $filename"
        echo "Official youtube channel not specifying artist, so renamed file into '$renamed'"
        mv "$filename" "$renamed"
        filename=$renamed
    fi
    # Extract them from filename if not defined
    if [[ -z $artist ]] || [[ -z $track ]];
    then
        local parse_filename="--parse-filename"
        echo "Missing artist or track name from downloaded file, will try to extract from filename."
    else
        echo Leaving downloaded track default\'s artist="$artist" \&\& track="$track"
    fi

    # move to save directory
    moved_file=$(print_out_dir "$filename" "${@}" )
    ytlog "Saved '$moved_file'"
    mv "$filename" "$moved_file" 2> /dev/null

    # Logs
    if [[ -d "$YTDL_HISTORY_DIR" ]] ; then
        echo "$(date -Im) $moved_file" >> "$YTDL_HISTORY_DIR/$(date -I).txt"
    fi

    # edit ID3 tags
    edit_id3tags "$moved_file" $parse_filename "$@"
}

# @brief: Edit MP3 file ID3 tags
# @arg1:  Filename
# @args: parse-filename         # extract artist & title from filename
# @args: genre=GENRE1;GENRE2   # Initialize genres list
# @args: genre+=GENRE2;GENRE3  # Add other genres
# @args: comment="your comment"
# @args: artist="Artist name"
# @args: song="Track name"
declare -A genres_by_file
function edit_id3tags() {
    # First split given parameters between filenames & actions
    local files=()
    local common_actions=()
    local parse_filename=false
    local set_genres=""
    local add_genres=()
    for arg; do 
        if [[ $arg == "lvl="* ]] ; then
            continue # Only used for print_out_dir
        elif [[ $arg == "parse-filename" ]] ; then 
            parse_filename=true
        elif [[ $arg == "genre+="* ]] ; then
            IFS=";" read -r -a new_genres <<< "${arg:7}"
            add_genres=( "${add_genres[@]}" "${new_genres[@]}" )
        else # mid3v2 options
            # handle command parameters
            if [[ $arg == "artist="* ]] || [[ $arg == "song="* ]] || [[ $arg == "comment="* ]] ; then
                common_actions+=( "--$arg")
            elif [[ $arg == "genre="* ]] ; then 
                # in order to prevent default mid3v2 behaviour given multiple '--genre', keep only the last value
                # (mid3v2 would behave as if second '--genre'' was a '+=', making difficult use of default genres for session mode & using a '/' as separator)
                set_genres=${arg:6}
            elif [[ -f "$arg" ]] ; then
                files+=( "$arg" )
            else
                echo "Unknown command or filename '$arg'"
            fi  
        fi
    done

    # Update genres DB for consistency of 'genre+=' command
    if [[ -n $set_genres ]] ; then
        for cur in "${files[@]}" ; do
            genres_by_file[$cur]=$set_genres
        done
        common_actions+=( "--genre=$set_genres" )
    fi

    # Apply common actions to every files at once
    if [[ ${#common_actions[@]} -gt 0 ]] ; then 
        mid3v2 "${common_actions[@]}" "${files[@]}"
    fi

    # Now go through each files to apply distinct updates
    for filepath in "${files[@]}" ; do
        local mid3_options=()
        # If add_genres, get current genres to concat them together
        if [[ ${#add_genres[@]} -gt 0 ]] ; then
            cur_genres=${genres_by_file[$filepath]}
            genres=( "${cur_genres[@]}" "${add_genres[@]}" )
            genres_by_file[$filepath]=$genres
            IFS=';'; mid3_options+=( "--genre=${genres[*]}" )
        fi

        if [[ $parse_filename == true ]] ; then
            filename=$(basename "$filepath")
            extracted=$(echo "$filename" | sed  's/^\([^-]*\) - \(.*\).mp3$/artist="\1" \&\& track="\2"/g')
            eval "$extracted 2> /dev/null"
            if [[ $? -eq 0 ]] ; then # Succesfully extracted some artist / song
                mid3_options+=( "--artist=$artist" "--song=$track" )
                echo "Extracted $extracted from '$filename'"
            else
                echo "Couldn't extract artist & track from filename '$filename'"
            fi
        fi
        # Apply !
        if [[ -n $mid3_options ]] ; then
            mid3v2 "${mid3_options[@]}" "$filepath" > /dev/null
        fi  
    done
}

# @brief: Start a multi-download session
# @args: default edit_id3tags options
function session_mode() {
    local default_params=$(printf "\"%s\" " "${@}")
    while read -p "URL ? > " request ; do
        IFS=" " read -r -a split <<< "$request"
        url=${split[0]}
        if [[ -z $url ]] ; then
            continue
        fi
        params="${split[@]:1}"
        eval "download \"$url\" $default_params $params"
    done
}

# @brief: Prints ID3 tags from a list of mp3 files
# @args:  mp3 files to scan
function print_tags() {
    local i=1
    local details=""
    local last_dirpath=""

    IFS=
    for filepath; do
        filename=$(basename "$filepath")
        dirpath=$(dirname "$filepath")

        # Print new directory change & save current tab number
        if [[ "$last_dirpath" != "$dirpath" ]] ; then
            last_dirpath="$dirpath"
            details+=">\n$dirpath\n"
        fi

        local all_tags=$(mid3v2 "$filepath")
        local artist=$(echo "$all_tags" | grep TPE1 | cut -d'=' -f2)
        local track=$(echo "$all_tags" | grep TIT2 | cut -d'=' -f2)        
        local genres=$(echo "$all_tags" | grep TCON | cut -d'=' -f2)
        local comment=$(echo "$all_tags" | grep COMM | rev | cut -d'=' -f1 | rev)
        genres_by_file[$filepath]=$genres
        details+="$i) $filename\tArtist='$artist'\tTrack='$track'\tGenres='$genres'\tComment='$comment'\n"
        ((i++))
    done
    echo -e $details | column -t -s $'\t'
}

# @brief: Start a tags edition session
# @args:  mp3 files to view/edit
function tags_editor() {
    print_tags "$@"

    # Select ranges
    while read -p "Select music index ranges to edit, 'p' to print ID3 tags or 'e' to exit : " selected_ranges ; do
        if [[ $selected_ranges == "e" ]] ; then
            return 0
        fi
        if [[ $selected_ranges == "p" ]] ; then
            print_tags "$@"
            continue
        fi
        local selected_files=""
        # Get filenames corresponding to seleted ranges
        IFS="," read -r -a splitted_ranges <<< "$selected_ranges"
        for range in ${splitted_ranges[@]} ;
        do
            # Is it a '1-5'-like range ?
            if [[ $range =~ ^[0-9]+-[0-9]+ ]] ; then
                IFS="-" read start end <<< "$range"
                let "nb=$end-$start+1"
                # Printf to keep doublequotes around each filename in the final eval
                selected_files+=$(printf "\"%s\" " "${@:$start:$nb}")
            elif [[ $range =~ ^[0-9]+ ]] ; then
                selected_files+="\"${@:$range:1}\" "
            else
                echo "Please type a valid range like 2,2 or 2-4"
                continue 2 # continue while read instead of for
            fi
        done
        if [[ ${#selected_files} -eq 0 ]] ; then
            continue
        fi

        # Ask for desired commands
        echo "Selected ${selected_files}"
        echo "Example commands: parse-filename artist='My artist' genre+='New genre' song='My track'"
        read -p "> " commands
        eval "edit_id3tags $commands $selected_files"
    done   
}

##################################################################
##### Main start
if [[ $1 == "tags" ]] ; then
    shift

    if [[ ${#@} -eq 0 ]] ; then
        tags_editor $SAVE_DIRECTORY/**/*.mp3
    else
        tags_editor "$@"
    fi
elif [[ $1 == "session" ]] ; then
    shift
    if [[ -d $1 ]] ; then
        SAVE_DIRECTORY=$1
        shift
    fi
    echo "Session mode. Will save every mp3 to '$SAVE_DIRECTORY'"
    session_mode "$@"
elif [[ $1 == "ff-watch" ]] ; then
    if [[ -f /tmp/ff_watch_daemon.pid ]] ; then
        echo "ytdl ff-watch already running"
        exit 0 
    fi
    echo "$$" > /tmp/ff_watch_daemon.pid
    python $LIST_FFTABS_SCRIPT watch | while IFS= read -r line; do
        if [[  $(echo "$line" | grep -E "$YOUTUBE_REGEX") ]] ; then
            echo "$line" > "$LAST_TAB_FILE"
        fi
    done
elif [[ $1 == "ff" ]] ; then
    shift
    # If we are given a title pattern to search that is not an ID3 option
    if [[ -n $1 ]] && [[ ! $(echo "$1" | grep -E "^(genre\+?|artist|song|comment|lvl)=") ]] ; then
        tab_title="$1"
        shift
        tab=$(python $LIST_FFTABS_SCRIPT find "$tab_title" | grep -E "$YOUTUBE_REGEX" | head -n1)
        if [[ -z "$tab" ]] ; then 
            ytlog "Did not find any tab corresponding to '$tab_title'"
            exit 1
        fi
        title=$(echo $tab | jq -r .title)
        url=$(echo $tab | jq -r .url)        
    # No search pattern, but we have last tab stored
    elif [[ -z "$tab_title" ]] && [[ -f "$LAST_TAB_FILE" ]] ; then
        title=$(cat "$LAST_TAB_FILE" | jq -r .title)
        url=$(cat "$LAST_TAB_FILE" | jq -r .url)
    else # No search pattern neither ff-watch enabled !
        ytlog "Firefox tab detection needs ytdl ff-watch to run in background"
        exit 1
    fi

    ytlog "Starting download '$title' ($url)"
    download "$url" "${@}"
else # single download
    download "$@"
fi