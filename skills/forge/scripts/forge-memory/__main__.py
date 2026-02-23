"""Allow running the package with ``python -m forge-memory`` or from the script dir."""
import os
import sys

# Ensure the package directory is on sys.path
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

from cli import main

main()
