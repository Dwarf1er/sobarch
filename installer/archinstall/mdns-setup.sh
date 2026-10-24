#!/bin/bash
# Lets glibc resolve .local names through avahi (nss-mdns). avahi-daemon
# itself is enabled via archinstall's services list.

set -euo pipefail

if ! grep -q '^hosts:.*mdns_minimal' /etc/nsswitch.conf; then
    sed -i '/^hosts:/ s/\(mymachines \)\?resolve /mdns_minimal [NOTFOUND=return] &/' /etc/nsswitch.conf
fi
grep -q '^hosts:.*mdns_minimal' /etc/nsswitch.conf
