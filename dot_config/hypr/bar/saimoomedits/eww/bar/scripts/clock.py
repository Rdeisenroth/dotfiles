import time
import json
import argparse
from datetime import datetime

# Create the parser
parser = argparse.ArgumentParser(description='Process some integers.')
parser.add_argument('--current', action='store_true',
                    help='print the current time and exit')

# Parse the arguments
args = parser.parse_args()

# Function to print the current time
def print_time(now):
    # Format the time components as a dictionary
    time_dict = {
        'second': now.strftime("%S"),
        'minute': now.strftime("%M"),
        'hour': now.strftime("%H"),
        'date': now.strftime("%d.%m.%Y")
    }

    # Output the time components in JSON format
    print(json.dumps(time_dict), flush=True)

# If --current is passed, print the current time and exit
if args.current:
    print_time(datetime.now())
    exit()

# Otherwise, print the time every second
while True:
    # Get the current time
    now = datetime.now()
    
    print_time(now)

    # Sleep until the start of the next second
    time.sleep(1 - now.microsecond / 1000000.0)