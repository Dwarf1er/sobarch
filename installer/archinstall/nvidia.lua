-- NVIDIA-specific Hyprland environment variables.
--
-- This file is NOT part of configs/skel/ and is never copied to every
-- install. It is deployed to ~/.config/hypr/nvidia.lua only by the
-- first-boot hook, only when the installer's hardware
-- detection (installer/archinstall/hardware-detect.sh) finds an
-- NVIDIA GPU. Setting these env vars unconditionally on AMD/Intel-only
-- systems would break VAAPI/EGL there, so this can't just live in
-- hyprland.lua directly the way most other config does.
--
-- Loaded from hyprland.lua the same way as local.lua: safe to be
-- absent (pcall(dofile, ...)), so AMD/Intel systems that never receive
-- this file are unaffected.

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- AQ_DRM_DEVICES: only relevant on hybrid Intel+NVIDIA laptops, to tell
-- Aquamarine (Hyprland's rendering backend) to use the integrated GPU
-- as primary with the NVIDIA GPU as secondary. Needs this specific
-- machine's actual /dev/dri/cardN paths (primary:secondary), which
-- hardware-detect.sh does not currently resolve automatically (it
-- would need to, since guessing wrong here is worse than leaving it
-- unset). Left commented out until that's addressed; uncomment and
-- fill in manually for now on a hybrid laptop.
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
