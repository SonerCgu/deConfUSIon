deConfUSIon MODERN THEME PACK v6
================================

Purpose
-------
High-resolution, visual-only redesign of the deConfUSIon Studio shell.

What is new in v6
-----------------
- section icons are newly coded as vector SVG artwork and exported at 1024 x 1024 PNG resolution
- matching high-resolution brain/deConfUSIon icon in the top-left
- section titles are centered, larger, Helvetica, and bold
- section cards are drawn as true vector rounded rectangles inside MATLAB
- module buttons are custom vector rounded controls (no Windows grey disabled-button skin)
- disabled modules remain visibly dark/clean and are activated after dataset load exactly as before
- footer buttons are rounded vector controls too
- all visual objects are created once at startup; no processing loop was added

What does NOT change
--------------------
- analysis algorithms
- callback mapping
- data structures
- load/save behavior
- processing functions

Files replaced / added
----------------------
- fusi_studio_GUI.m
- fusi_studio_callback.m   (only modern-button enable handling + previous visual status changes)
- studio_load_options_dark_dialog.m
- theme_icons/*.png
- theme_icons/*.svg

Installation
------------
1. Extract this folder anywhere.
2. In MATLAB, cd into this theme-pack folder.
3. Run:

   install_deConfUSIon_modern_theme

A timestamped backup is created automatically inside your deConfUSIon folder.
The split runtime cache is deleted so the GUI is rebuilt on next launch.

Then launch normally:

   deConfUSIon

Revert
------
Run:

   restore_deConfUSIon_pre_theme

MATLAB note
-----------
The rounded cards and buttons in v6 are not raster screenshots. They are drawn
with MATLAB vector rectangle objects and custom click handling, which preserves
sharp corners/curves at different screen resolutions and avoids native disabled
pushbutton greying.
