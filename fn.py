import subprocess
from pynput import keyboard

# Key to trigger layout switch
TOGGLE_KEY = keyboard.Key.media_play_pause  # can be replaced with another key

# Paths and layout IDs
ISSW_CMD = '/usr/local/bin/issw'
LAYOUT_ABC = 'com.apple.keylayout.ABC'
LAYOUT_RU = 'com.apple.keylayout.Russian'

def get_current_layout():
    """Return the current keyboard layout."""
    try:
        return subprocess.check_output([ISSW_CMD], text=True).strip()
    except subprocess.CalledProcessError:
        return None

def switch_layout():
    """Toggle between ABC and Russian layouts."""
    current = get_current_layout()
    if current == LAYOUT_ABC:
        subprocess.run([ISSW_CMD, LAYOUT_RU])
    else:
        subprocess.run([ISSW_CMD, LAYOUT_ABC])

def on_press(key):
    try:
        if key == TOGGLE_KEY:
            switch_layout()
    except AttributeError:
        pass  # ignore keys without char attribute

if __name__ == "__main__":
    # Start keyboard listener
    with keyboard.Listener(on_press=on_press) as listener:
        listener.join()
