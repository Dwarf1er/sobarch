#!/bin/bash
# Makes the base install's TLP actually do something: the package alone
# only ships the units, it doesn't enable them.
#
# - tlp.service applies the power settings at boot and on resume.
# - tlp-pd.service exposes the power-profiles-daemon D-Bus interface on
#   top of TLP, backing the Power Profile menu (`tlpctl`).
# - NetworkManager-dispatcher.service lets tlp-rdw (radio device wizard)
#   react to NetworkManager events; it is disabled by default.
# - systemd-rfkill.service/.socket are masked because they compete with
#   TLP for saving and restoring radio state (TLP's own documentation
#   asks for this, and `tlp-stat -s` warns when they are left running).

set -euo pipefail

# TLP is only installed on laptops.
pacman -Q tlp >/dev/null 2>&1 || exit 0

systemctl enable tlp.service tlp-pd.service NetworkManager-dispatcher.service
systemctl mask systemd-rfkill.service systemd-rfkill.socket
