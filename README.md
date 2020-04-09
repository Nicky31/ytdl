# ytdl
ytdl combines [youtube-dl](https://github.com/ytdl-org/youtube-dl) for youtube mp3 downloading and [mid3v2](https://github.com/quodlibet/mutagen/blob/master/docs/man/mid3v2.rst) for proper ID3v2 tagging.  
On top of them, a few improvements have been done to enhance tags consistency & fasten their edition :
* youtube-dl defaults settings to only download audio as 320K mp3. When given a playlist URL, only download the specified video instead of the whole playlist.
* Clean-up of noisy patterns like "(Original Mix)" or "(Official Video)" in filename
* When downloading from official youtube channels which do not indicate artist name in the video title, output file is renamed accordingly : *Artist - Track.mp3*.
* When artist or track name is missing from downloaded ID3 tags and only in this case, attempt to extract them from filename. Exact same behaviour as youtube-dl `--metadata-from-title "%(artist)s - %(title)s"`, but applied only in the event of missing tags since that video titles are often more prone to errors than ID3 tags.
* All mp3 files are saved to the `$SAVE_DIRECTORY` directory, whose default value is written at the beginning of the script.
* 3 differents usage mode : **single download** mode lets you download & edit tags at once, **session** lets you provide default tags for the video URLs you feed in standard input, and **tags edition** lets you view and edit tags of multiples files.
* `genre+=` concatenates new genres to those already existing, separated with a `;`

## Requirements
* youtube-dl
* jq
* mid3v2
* bash 4+

## Usage

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

