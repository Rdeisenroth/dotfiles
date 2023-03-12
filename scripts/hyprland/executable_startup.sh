#! /bin/bash

# This script is used to start applications and set environment variables for the hyprland WM.
export __GL_GSYNC_ALLOWED=1
export __GL_VRR_ALLOWED=0
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM="wayland;xcb"
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_QPA_PLATFORMTHEME=qt5ct
export GBM_BACKEND=nvidia-drm
export NVD_BACKEND=direct
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export LIBVA_DRIVER_NAME=nvidia
export XDG_SESSION_TYPE=wayland
export WLR_NO_HARDWARE_CURSORS=1
export _JAVA_AWT_WM_NONEREPARENTING=1
export CLUTTER_BACKEND="wayland"
exec Hyprland
