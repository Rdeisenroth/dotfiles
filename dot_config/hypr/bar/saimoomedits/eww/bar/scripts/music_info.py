#!/usr/bin/env python3

import dbus
import subprocess
import json

def process_metadata():
    player = dbus.SessionBus().get_object('org.mpris.MediaPlayer2.playerctld', '/org/mpris/MediaPlayer2')
    metadata = player.Get('org.mpris.MediaPlayer2.Player', 'Metadata', dbus_interface='org.freedesktop.DBus.Properties')
    music_dict = {
        'status': metadata['PlaybackStatus'],
        'player': metadata['PlayerName'],
        'artist': metadata['xesam:artist'][0],
        'title': metadata['xesam:title']
    }
    print(json.dumps(metadata, indent=2), flush=True)

def main():
    # Start playerctl process
    process = subprocess.Popen(
        ['playerctl', '--follow', 'metadata', "-f", '{{status}},{{playerName}},{{artist}},{{title}}'],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True  # Ensure text mode (handles strings instead of bytes)
    )
    
    try:
        for line in process.stdout:
                    process_metadata()
    except KeyboardInterrupt:
        # Handle script termination with Ctrl+C
        print("Process terminated by user.")
    finally:
        process.terminate()  # Terminate the subprocess when done

if __name__ == '__main__':
    main()
