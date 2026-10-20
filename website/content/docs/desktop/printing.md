+++
title = "Printing"
description = "Setting up CUPS from the Printing software profile."
weight = 37
template = "docs/page.html"

[extra]
lead = "Printing is opt-in: no print daemon runs unless you install it."
toc = true
+++

Install the **Printing** [software profile](../../installer/software-profiles/)
from the installer or from **Sobarch, Install Apps**. It adds `cups`,
`cups-filters` and `cups-pdf` (a virtual printer that writes PDFs).

Installing the packages doesn't start anything. Enable the service once:

```sh
sudo systemctl enable --now cups.socket
```

The socket starts CUPS on demand. Then open <http://localhost:631> in a
browser, choose **Administration, Add Printer**, and sign in with your
account. For a network printer, enter its address as
`ipp://<printer>/ipp/print` and pick the driverless "IPP Everywhere"
model.

CUPS listens on localhost only, and the [firewall](../../reference/security/) blocks
incoming connections, so a printer on your network is reachable but your
machine isn't offering print services to it. Network printer discovery
(Avahi) is not set up; add printers by address.
