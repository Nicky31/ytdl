# ytdl
ytdl combines [youtube-dl](https://github.com/ytdl-org/youtube-dl) for youtube mp3 downloading and [mid3v2](https://mutagen.readthedocs.io/en/latest/man/mid3v2.html) for proper ID3v2 tagging.    
In addition, `ytdl ff` integrates [this script](https://gist.github.com/tmonjalo/33c4402b0d35f1233020bf427b5539fa) to detect and download opened youtube tabs with their title autocompletion.

On top of them, a few improvements have been done :
* 4 differents usage modes :
    * **firefox mode** automatically downloads last opened Firefox Youtube tab or any youtube tab matching with given parameter. Can be used from rofi/dmenu equivalent with status messages sent through `notify-send`
    * **single download mode** lets you download & edit tags at once
    * **session mode** lets you provide default tags for multiple video URLs you feed in standard input, each of which can have their specifics tags 
    * **tags edition mode** lets you view and edit tags of multiples files.
* All mp3 files are saved to the `$SAVE_DIRECTORY` directory, whose default value is written at the beginning of the script.
* `level_dirs` and `genre_dirs` script variables allow custom subdirectories to be automatically appended depending on energy level / genre.
* Each download is logged to a log file inside `$YTDL_HISTORY_DIR/` directory.
* youtube-dl defaults settings to only download audio as 320K mp3. When given a playlist URL, only download the specified video instead of the whole playlist.
* Clean-up of noisy patterns like "(Original Mix)" or "(Official Video)" in filenames
* When downloading from official youtube channels which do not indicate artist name in the video title, output file is renamed accordingly : *Artist - Track.mp3*.
* When artist or track name is missing from downloaded ID3 tags and only in this case, attempt to extract them from filename. Exact same behaviour as youtube-dl `--metadata-from-title "%(artist)s - %(title)s"`, but applied only in the event of missing tags since that video titles are often more prone to errors than ID3 tags.
* `genre+=` concatenates new genres to those already existing, separated with a `;`

## Requirements
* [youtube-dl](https://github.com/ytdl-org/youtube-dl)
* jq
* [mid3v2](https://mutagen.readthedocs.io/en/latest/man/mid3v2.html)
* bash 4+

## Enable firefox mode
* First install `python3` and `lz4` python package.
* At the beginning of `ytdl.sh`, make sure `$LST_FFTABS_SCRIPTS` points to `list-fftabs.py`
* To enable Firefox tab autocompletion, add `source PATH_TO/ff_tabs_autocomplete.sh` to your .bashrc or .zshrc
    * For zshrc to work with bash autocompletion, you need to add this line before sourcing : `autoload bashcompinit && bashcompinit`
    * oh-my-zsh also needs `wp-cli` plugin
* To lets `ytdl ff` download last opened youtube tab without specifying its name, run `ytdl ff-watch` in background (i.e at the end of your bashrc)

## Usage

### Firefox mode

Download last opened tab :
```
ytdl ff
```

Download any tab matching with "boiler room" : 
```
ytdl ff boiler room
```

### Single download mode

Without any tag, from an officiel youtube channel : 
```
#> ytdl http://youtube.com/some_video
Downloading http://youtube.com/some_video ...
Downloaded 'MyTrack.mp3'.
Official youtube channel not specifying artist, so renamed file into 'OfficialName - MyTrack.mp3'
Leaving downloaded track default's artist=OfficialName && track=MyTrack
Moved mp3 to '/my/save/directory/OfficialName - MyTrack.mp3'
```


With every possible tags : 
```
#> ytdl http://youtube.com/some_video artist="My artist" song="My song" comment="some comment" genre="first genre" genre+="new genre" ...
Downloading http://youtube.com/some_video ...
Downloaded 'MyArtist - MyTrack.mp3'.
Leaving downloaded track default's artist=MyArtist && track=MyTrack
Moved mp3 to '/my/save/directory/MyArtist - MyTrack.mp3'
```

### Session mode

With no default tags: 
```
#> ytdl session [OPTIONAL_OUTPUT_DIR]
#> http://youtube.com/first_video_without_tags
...
#> http://youtube.com/2nd_with_some_tags genre="Rock;Indie" comment="u flyin"
...
```
When output dir is not specified, defaults to `$SAVE_DIRECTORY` (or its default value).

With default tags :
```
#> ytdl session genre="Rock" comment="they are all great"
#> http://youtube.com/first_video genre+="Indie"
#> http://youtube.com/not_so_rocky genre="Pop" genre+="Electro"
```

### Tags edition

```
#> ytdl tags [OPTIONAL_MP3_GLOBBING]
/my/save/directory/Rap
1) Jehst - Liquid diction.mp3          Artist='Jehst'          Track='Liquid diction'  Genres='Rap'    Comment=''
2) Lighter Shade - Shaolin Angel.mp3   Artist='Lighter Shade'  Track='Shaolin Angel'   Genres='Rap'    Comment=''
Select music index ranges to edit, 'p' to print ID3 tags or 'e' to exit :
#> 1-2
Selected "/my/save/directory/Rap/Jehst - Liquid diction.mp3" "/my/save/directory/Rap/Lighter Shade - Shaolin Angel.mp3"
#> genre+="Oldschool"
Select music index ranges to edit, 'p' to print ID3 tags or 'e' to exit :
#> p
1) Jehst - Liquid diction.mp3          Artist='Jehst'          Track='Liquid diction'  Genres='Rap;Oldschool'    Comment=''
2) Lighter Shade - Shaolin Angel.mp3   Artist='Lighter Shade'  Track='Shaolin Angel'   Genres='Rap;Oldschool'    Comment=''
```
When no globbing is provided, defaults to all mp3 files recursively found in `$SAVE_DIRECTORY` (or its default value).

