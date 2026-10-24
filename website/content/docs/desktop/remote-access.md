+++
title = "Remote Access"
description = "Streaming a sobarch desktop to another machine with Sunshine and Moonlight, at home or over your own WireGuard tunnel."
weight = 38
template = "docs/page.html"

[extra]
lead = "Sunshine streams a machine's desktop, Moonlight views and controls it, and a WireGuard tunnel you host yourself carries it across the internet. No third-party service is involved."
toc = true
+++

Install the **Remote Access** [software profile](../../installer/software-profiles/)
from the installer or from **Sobarch, Install Apps**. It adds:

- `sunshine-bin`: the streaming host, on the machine you want to reach.
- `moonlight-qt`: the client, on the machine you connect from.
- `wireguard-tools`: for the VPN menu, used when you connect from
  outside your home network.

Install it on both machines; it's harmless on the one that doesn't need
a given part. Nothing starts by itself: Sunshine stays off until you
turn it on.

Why Sunshine and not a tool like RustDesk? Remote control on Wayland goes
through the desktop portal's `RemoteDesktop` interface, and Hyprland's
portal doesn't provide it, so those tools can view a Hyprland session but
can't control it. Sunshine captures the screen and injects input
directly.

## At home, on the same network

### On the host

Open **Super, System, Remote Access** and choose **Start Sunshine**. The
first time, choose **Open Web UI** (`https://localhost:47990`), accept the
browser's certificate warning (Sunshine uses a self-signed one), and
create the admin username and password.

Sobarch opens Sunshine's streaming ports in the firewall while
`sunshine-bin` is installed. The web UI port stays closed, so that page
is reachable only from the host itself.

Sunshine offers two apps: **Desktop**, which streams one monitor, and
**Steam Big Picture**.

### On the client

1. Open Moonlight. The host should appear by its name: every sobarch
   install runs Avahi, so mDNS discovery works on the local network. If
   it doesn't, choose **Add Host** and enter the host's IP address.
2. Click the host. Moonlight shows a 4-digit PIN.
3. On the host, open the Sunshine web UI, go to the **PIN** tab, enter the
   PIN and give the device a name. Moonlight shows the host as paired.
4. Pick **Desktop** to start streaming.

You only pair once per client.

### A virtual monitor just for Moonlight

By default Sunshine streams one of your real monitors. **Virtual Monitor**
in the Remote Access menu is a setting that changes that. When it's on,
starting Sunshine also creates a separate 1920x1080 screen that exists
only for the stream, parked where the cursor can't reach it, and points
Sunshine at it. Stopping Sunshine removes it. Your real monitors and
workspaces are unchanged.

It's still one session: windows, keyboard focus and the clipboard are
shared between whoever is at the machine and whoever is streaming. Think
of it as an extra screen, not a second login. Windows don't move to it by
themselves; open or move them there from the stream.

### Keyboard shortcuts

Both machines run the same keybindings, so decide where `Super` should
go. In Moonlight's settings, **Capture system keyboard shortcuts** set to
*Only in fullscreen* keeps your local shortcuts while the stream is in a
window and sends everything to the host in fullscreen.

You can always get control back with Moonlight's own shortcuts, which it
keeps even while capturing everything:

| Shortcut | Action |
| --- | --- |
| `Ctrl+Alt+Shift+Z` | Release the keyboard and mouse back to your machine |
| `Ctrl+Alt+Shift+X` | Toggle fullscreen |
| `Ctrl+Alt+Shift+Q` | End the stream |

They're also listed in the keybindings cheat sheet (`Super+/`) when
Moonlight is installed. On a Mac keyboard, `Alt` is `Option`.

## From outside your home

Moonlight needs a network path to the host. Instead of exposing Sunshine
to the internet, sobarch sets up a private WireGuard tunnel between your
machines. The host's side of it runs on the same machine as Sunshine, and
it works with your own router; only one setting on it has to change.

You need:

- A public address for your home connection that isn't shared with other
  customers. Check this first: log in to your router (or the ISP's modem
  if that's a separate device), note its WAN or Internet IP address, and
  compare it with what `curl ifconfig.me` prints on the host. If they
  differ, your provider uses carrier-grade NAT, and no port forward can
  reach you.
- Access to the router's port-forwarding page.

### 1. Set up the server

On the host, open **Super, System, VPN** and choose **Set Up Server**.
Enter your home's public IP address or a hostname that points to it.
Sobarch can't look this up for you without asking an outside website, so
you enter it. If your address changes, use **Public Address** later; that
setting only applies to devices you add afterwards.

This creates a WireGuard interface (`wg0`, address `10.8.0.1`) and opens
UDP port `51820` in the firewall. The port opens only now, and closes
again if you remove the server.

### 2. Forward the port on your router

Create a port forward with these values. Field names vary by router:

| Setting | Value |
| --- | --- |
| Protocol | UDP only |
| WAN (external) port range | `51820` to `51820` |
| LAN (internal) port range | `51820` to `51820` |
| Destination / LAN IP | the host's address on your network |

Also give the host a fixed address with a DHCP reservation, so the
forward doesn't break when its address changes. Mesh nodes and extenders
usually don't have this page; use the gateway or modem they connect to.

### 3. Add a device

Still in the VPN menu on the host, choose **Add Device** and name it (for
example `laptop`). Each device gets its own keys and its own address
(`10.8.0.2`, `10.8.0.3`, ...), and only traffic for the host goes
through the tunnel.

- **A phone or other device with the WireGuard app:** scan the QR code.
- **Another sobarch machine:** the config is saved as
  `~/.config/sobarch/wireguard/NAME.conf`. Copy it across (for example
  with LocalSend), or copy its contents to the clipboard.

The config contains that device's private key. Delete the file once it's
imported, and treat it like a password.

### 4. Connect from the client

On the other sobarch machine, open **System, VPN, Import Config** and pick
the file (the list shows `.conf` files in your home folder, Downloads and
`~/.config/sobarch/wireguard`) or choose **Paste from Clipboard**. The
tunnel appears under **Tunnels**; press `Enter` on it to turn it on or
off. It doesn't start by itself at boot.

### 5. Test it

Test from a different network, such as a phone's hotspot. From inside your
own network the public address often doesn't work even when everything is
correct, because many routers can't loop traffic back to their own public
address.

1. With the tunnel on, run `ping -c3 10.8.0.1` on the client. Replies mean
   the tunnel works.
2. On the host, `sudo wg show` lists each device with its latest
   handshake. A recent one means packets are arriving.
3. In Moonlight, choose **Add Host** and enter `10.8.0.1`. mDNS discovery
   doesn't cross the tunnel, so you add it by hand once. Pair with the PIN
   as before if this client hasn't paired yet, then stream.

Turn the server on or off, remove a device, or remove the server from the
same menu. Removing a device cuts its access immediately.

### If it doesn't work

- **No handshake on the host, and the ping fails:** packets aren't getting
  in. Check that the forward is saved, uses UDP, and points to the host's
  current address; that you're not behind carrier-grade NAT; and that the
  device's config uses your public address (not the LAN one).
- **Handshake appears but the ping fails:** the firewall. On the host,
  `sudo nft list chain inet filter input | grep sobarch` should list
  rules for WireGuard (UDP `51820`) and, if Sunshine is installed, for
  Sunshine. If it prints nothing, see the next section.
- **Ping works but Moonlight can't connect or pair:** make sure Sunshine is
  running (the Remote Access menu shows its state) and that you entered
  `10.8.0.1`.
- **Moonlight can't find the host on the home network:** Avahi has to be
  running on both machines (`systemctl is-active avahi-daemon`), and
  Sunshine must have started after it. If you started Sunshine first,
  restart it from the menu.
- **Streaming shows the wrong monitor:** Sunshine only reads its monitor
  setting when it starts. Restart it from the menu after changing
  **Virtual Monitor**; the menu does this for you.

## Systems installed before Remote Access

New installs get everything above automatically. A machine installed
earlier receives the new menus and scripts through **Update System**, but
not the system changes underneath them, because those are applied once at
install time. Without them the firewall rules disappear at the next
reboot. On each such machine:

1. Install the packages: `sudo pacman -S --needed avahi nss-mdns
   wireguard-tools`, then **Install Apps** for the Remote Access profile
   (or `moonlight-qt` and `sunshine-bin` individually).
2. Turn on mDNS: `sudo systemctl enable --now avahi-daemon`, then let
   hostnames resolve through it:

   ```sh
   sudo sed -i '/^hosts:/ s/\(mymachines \)\?resolve /mdns_minimal [NOTFOUND=return] &/' /etc/nsswitch.conf
   ```

3. Teach the firewall about exception files. In `/etc/nftables.conf`, remove
   any Sunshine rules you added by hand, then add these lines to the
   `input` chain after the LocalSend rules, and load the file:

   ```
   # mDNS
   udp dport 5353 accept

   # Exceptions added by firewall-open.sh (Sunshine, WireGuard)
   include "/etc/nftables.d/*.nft"
   ```

   ```sh
   sudo mkdir -p /etc/nftables.d
   sudo nft -c -f /etc/nftables.conf && sudo nft -f /etc/nftables.conf
   ```

   Then on a Sunshine host, `sudo /usr/local/lib/sobarch/firewall-open.sh sync
   sunshine sunshine-bin` writes its rule file. The WireGuard one is
   written when you set up the server.

See [Security](../../reference/security/) for everything the firewall opens
and why.
