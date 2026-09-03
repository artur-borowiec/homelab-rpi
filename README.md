# homelab-rpi

Documentation for my Raspberry Pi homelab setup running a 64-bit OS.

## Hardware

- **Board:** Raspberry Pi 3 Model B

## Setup

### Flash OS to SD card

Used [Raspberry Pi Imager](https://www.raspberrypi.com/software/) on macOS to write the OS image to the SD card.

### Initial setup

- SSH access — see [SSH access (macOS + 1Password)](#ssh-access-macos--1password) below
- [Tailscale](https://tailscale.com/) — see [Tailscale](#tailscale) below

#### SSH access (macOS + 1Password)

SSH keys live in [1Password](https://developer.1password.com/docs/ssh/get-started). The private key never goes on disk — the 1Password SSH agent signs requests after you approve (e.g. Touch ID).

**Clean up a previous setup (optional)**

Do this on your Mac if you re-flashed the Pi, changed its IP, or are redoing SSH setup.

1. Remove stale host keys from `~/.ssh/known_hosts`. A re-flash generates a new host key; the old one triggers `REMOTE HOST IDENTIFICATION HAS CHANGED` or ssh-copy-id asking you to fix `known_hosts`:

```bash
ssh-keygen -R <pi-ip>
ssh-keygen -R raspberrypi.local    # if you connected by mDNS before
```

Run `ssh-keygen -R` for every hostname or IP you used for this Pi. Use the literal address (not the `Host` alias from `~/.ssh/config`).

2. Edit `~/.ssh/config` and delete any old `password-auth-ssh` or `homelab-rpi` blocks from a previous attempt.

3. Keep `~/.ssh/homelab-rpi.pub` if it is still the same key from 1Password. Re-export from 1Password only if you rotated the key.

On a re-flashed Pi, `~/.ssh/authorized_keys` is empty — run step 3 below from scratch. If the Pi was not re-flashed, `ssh-copy-id` is safe to run again (it skips a key that is already installed).

**Add the Pi host key**

SSH stores each server's host key in `~/.ssh/known_hosts` on first connect. After cleanup above, add the current key before `ssh-copy-id` (or accept the prompt when SSH asks `Are you sure you want to continue connecting?`):

```bash
ssh-keyscan -H <pi-ip> >> ~/.ssh/known_hosts
```

Replace `<pi-ip>` with the Pi's address. `-H` stores a hashed hostname (recommended on macOS).

**1. Enable the 1Password SSH agent (Mac)**

1. Open 1Password → **Settings** → **Developer**
2. Turn on **Use the SSH agent**
3. Optional: **Settings** → **General** → enable **Keep 1Password in the menu bar** and **Start at login**

**2. Configure SSH on macOS**

Add to `~/.ssh/config` (create the file if needed):

```
Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

Optional symlink for a shorter path:

```bash
mkdir -p ~/.1password && ln -sf ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ~/.1password/agent.sock
```

**3. Install the public key on the Pi**

1. In 1Password, open your SSH Key item and copy the **public key** (or download it)
2. Save it on your Mac as `~/.ssh/homelab-rpi.pub`
3. Add a temporary host entry to `~/.ssh/config`. Open the file on your Mac:

```bash
nano ~/.ssh/config
```

The Pi does not have your key yet, so the first login must use the Pi user password. That sounds like plain `ssh pi@<pi-ip>`, but step 2 already pointed SSH at the 1Password agent — on connect, the agent tries every stored key before SSH falls back to a password. With several keys, the Pi rejects the attempts (`Too many authentication failures`) and you never get a password prompt. This block is a one-time bootstrap alias: it tells SSH to skip public keys and ask for the password only. Paste it at the end of the file, save (`Ctrl+O`, Enter), and exit (`Ctrl+X`):

```
Host password-auth-ssh
  HostName <pi-ip>
  User pi
  PubkeyAuthentication no
  PreferredAuthentications password
  IdentitiesOnly yes
```

- `PubkeyAuthentication no` — do not offer keys
- `PreferredAuthentications password` — use password auth only
- `IdentitiesOnly yes` — ignore keys from the 1Password agent

4. Copy the public key to the Pi. The private key lives in 1Password, not on disk, so pass `-f` to tell `ssh-copy-id` to use the `.pub` file alone:

```bash
ssh-copy-id -f -i ~/.ssh/homelab-rpi.pub password-auth-ssh
```

Enter the Pi user password when prompted. You can remove the `password-auth-ssh` block from `~/.ssh/config` after key login works.

**4. Add a host entry on macOS**

Pin this Pi to your 1Password key (avoids "too many authentication failures" when you have many keys):

```
Host homelab-rpi
  HostName <pi-ip>
  User pi
  IdentityFile ~/.ssh/homelab-rpi.pub
  IdentitiesOnly yes
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

**5. Connect**

```bash
ssh homelab-rpi
```

1Password will prompt to authorize the key on first use. Verify the agent sees your key:

```bash
ssh-add -l
```

#### Tailscale

[Tailscale](https://tailscale.com/) runs on the Pi host (not in Docker) so the node joins your tailnet with a stable `100.x.x.x` address and MagicDNS hostname. Set up SSH first — you need LAN access to install and authenticate Tailscale.

**1. Install on the Pi**

SSH in (`ssh homelab-rpi`), then:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Open the auth URL in your browser and approve the Pi. Confirm it joined the tailnet:

```bash
tailscale status
```

Note the Pi's MagicDNS name (e.g. `raspberrypi.<tailnet>.ts.net`).

**2. Add a host entry on macOS**

Add a second SSH alias for remote access over Tailscale. Use the same key as `homelab-rpi`:

```
Host homelab-rpi-ts
  HostName raspberrypi.<tailnet>.ts.net
  User pi
  IdentityFile ~/.ssh/homelab-rpi.pub
  IdentitiesOnly yes
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

Replace `<tailnet>` with your tailnet suffix from `tailscale status`.

**3. Connect**

```bash
ssh homelab-rpi-ts
```

Accept the new host key on first connect (or pre-add it with `ssh-keyscan -H raspberrypi.<tailnet>.ts.net >> ~/.ssh/known_hosts`).

| Host | When to use |
| --- | --- |
| `homelab-rpi` | On your home LAN |
| `homelab-rpi-ts` | Anywhere via Tailscale |

Install the [Tailscale app](https://tailscale.com/download) on your Mac too — SSH over Tailscale requires your Mac to be on the same tailnet.

## Tools

- [CUPS](https://www.cups.org/) — print server
- [Docker](https://www.docker.com/) — see [Docker](#docker) below

### CUPS

Runs on the host (not in Docker) so the Pi can use USB or network printers directly.

Install on the Pi:

```bash
sudo apt update && sudo apt install -y cups avahi-daemon
sudo usermod -aG lpadmin $USER
sudo cupsctl --remote-admin --remote-any --share-printers WebInterface=yes
sudo systemctl enable --now cups avahi-daemon
```

Log out and back in (or reconnect SSH) so the `lpadmin` group applies.

1. Plug in the printer (USB or ensure it is reachable on the network)
2. Open the admin UI from your Mac: `https://<pi-ip>:631`
3. **Administration** → **Add Printer** → pick the printer, install the driver, enable **Share This Printer**

`avahi-daemon` advertises shared printers on the LAN (AirPrint/Bonjour on Apple devices). For HP printers, install `hplip` if CUPS does not detect the model: `sudo apt install -y hplip`.

**Admin UI won't open from the Mac**

If `https://raspberrypi.local:631` (or `https://<pi-ip>:631`) fails with *connection refused*, CUPS is probably installed but not running, or not listening on the network. If the port is open but the page is blank or missing **Administration**, the web UI may be disabled — `WebInterface=yes` enables it. On the Pi:

```bash
sudo systemctl enable --now cups avahi-daemon
sudo usermod -aG lpadmin $USER
sudo cupsctl --remote-admin --remote-any --share-printers WebInterface=yes
sudo systemctl restart cups
```

Confirm CUPS is listening on port 631:

```bash
ss -tlnp | grep 631
```

Then retry from the Mac. Browsers warn about CUPS's self-signed HTTPS certificate — proceed anyway. If `raspberrypi.local` is slow or fails, use the Pi IP directly (e.g. `https://192.168.100.25:631`).

## Docker

Application services run in Docker where it makes sense; system-level tools stay on the host.

### What runs in Docker

| Service | Docker? | Notes |
| --- | --- | --- |
| SSH | No | Host OS configuration |
| Tailscale | No | Install on the host for node-level VPN |
| CUPS | No | Needs direct USB/network printer access; native install is simpler |
| Home Assistant | Yes | Well supported via official container image |
| Nextcloud | Yes | Typical stack: Nextcloud + database via Compose |
| PostgreSQL | Yes | Shared database for Nextcloud and other apps |

The Pi 3B has only 1 GB RAM. Running Home Assistant and Nextcloud together in Docker can be tight — consider starting with one service first, or set memory limits on containers.

### Setup

Install Docker Engine on Raspberry Pi OS (64-bit):

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

Log out and back in so the `docker` group applies. Optionally install [Docker Compose](https://docs.docker.com/compose/install/) (included with recent Docker Engine packages).

## Plans

- [Home Assistant](https://www.home-assistant.io/)
- [Nextcloud](https://nextcloud.com/)
- [PostgreSQL](https://www.postgresql.org/) — in Docker, as the database for Nextcloud (and other services later)
