#! /usr/bin/env python3
# Source: https://gist.github.com/tmonjalo/33c4402b0d35f1233020bf427b5539fa

"""
List all Firefox tabs with title and URL
Supported input: json or jsonlz4 recovery files
Default output: title (URL)
Output format can be specified as argument
"""

import os
import sys
import time
import pathlib
import lz4.block
import json

path = pathlib.Path.home().joinpath('.mozilla/firefox')
files = list(path.glob('*default*/sessionstore-backups/recovery.js*'))

def get_opened_tabs(f):
    tabs = []
    b = f.read_bytes()
    if b[:8] == b'mozLz40\0':
        b = lz4.block.decompress(b[8:])
    j = json.loads(b)
    for w in j['windows']:
        for t in w['tabs']:
            i = t['index'] - 1
            tabs.append((
                t['entries'][i]['title'],
                t['entries'][i]['url'],
            ))
    
    return tabs

def watch(interval=1):
    last_mtimes = {}
    last_tabs = {}

    while True:
        try:
            for f in files:
                cur_mtime = os.stat(f).st_mtime
                if f not in last_mtimes: # Initialisation
                    last_mtimes[f] = cur_mtime
                    last_tabs[f] = get_opened_tabs(f)
                    continue 

                if cur_mtime == last_mtimes[f]:
                    continue # no change
                # File changed, print new tabs
                last_titles, last_urls = zip(*last_tabs[f])
                last_tabs[f] = get_opened_tabs(f)
                diff = set([url for _,url in last_tabs[f]]) - set(last_urls)
                if len(diff) > 0:
                    new_tabs = [
                        (title, url) for title, url in last_tabs[f] if url in diff
                    ]
                    print("\n".join([
                        '{{"title": "{}", "url":"{}"}}'.format(title, url) for title, url in new_tabs
                    ]))
                    sys.stdout.flush()
        except Exception as e:
            sys.stderr.write(str(e))   
        time.sleep(interval)

def print_tabs():
    for f in files:
        tabs = get_opened_tabs(f)
        print("\n".join([
            '{{"title": "{}", "url":"{}"}}'.format(title, url) for title, url in tabs
        ]))

def find(search):
    for f in files:
        tabs = get_opened_tabs(f)
        print("\n".join([
            '{{"title": "{}", "url":"{}"}}'.format(title, url) for title, url in tabs
            if search in title
        ]))    

if len(sys.argv) == 1:
    print_tabs()
else:
    if sys.argv[1] == "watch":
        watch()
    elif sys.argv[1] == "find":
        find(sys.argv[2])
