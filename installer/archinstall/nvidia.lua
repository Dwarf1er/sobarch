-- NVIDIA-specific Hyprland environment variables, deployed only when an
-- NVIDIA GPU is detected. They would break VAAPI/EGL on AMD/Intel systems.

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Hybrid Intel+NVIDIA laptops: set primary:secondary GPU to this machine's
-- /dev/dri/cardN paths. Not auto-detected, since a wrong guess is worse than none.
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
