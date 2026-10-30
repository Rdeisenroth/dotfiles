#!/usr/bin/env python3
import sys

# Best-effort mapping for "text produced by US layout" -> "intended text on DE layout"
# This is NOT a perfect keyboard-layout emulator; it's a practical password/email fixer.

TRANSLATE = str.maketrans({
    # letters
    "y": "z",
    "z": "y",
    "Y": "Z",
    "Z": "Y",

    # common DE layout differences (approx / frequently observed)
    "[": "ü",
    "{": "Ü",
    "]": "+",
    "}": "*",
    "\\": "ß",
    ";": "ö",
    ":": "Ö",
    "'": "ä",
    '"': "Ä",

    "`": "^",
    "~": "°",

    # password/email pain points (heuristics; adjust if annoying)
    # In many mismatches, people end up with " instead of @ when they wanted @ for email.
    # If you want that behavior, uncomment the next line and comment out the '"': 'Ä' above.
    # '"': "@",

    # Sometimes _ ends up as ? in mismatches (or vice versa). Uncomment if that matches you:
    # "?": "_",
})

def main():
    data = sys.stdin.read()
    sys.stdout.write(data.translate(TRANSLATE))

if __name__ == "__main__":
    main()
