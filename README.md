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
- [Xiaomi Cloud Tokens Extractor](#xiaomi-cloud-tokens-extractor) — macOS tool in `tools/` for Xiaomi device tokens

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

### Home Assistant

Runs in Docker as [Home Assistant Container](https://www.home-assistant.io/installation/linux#install-home-assistant-container) — the official image on your existing Raspberry Pi OS. This is not [Home Assistant OS](https://www.home-assistant.io/installation/raspberrypi) (a full replacement OS; official minimum is 2 GB RAM).

Home Assistant Container runs **Core only** — no Supervisor or one-click add-ons. Extra tools (Zigbee2MQTT, Node-RED, etc.) run as separate containers if needed later.

Requires Docker (see [Setup](#setup-1) above). On a Pi 3B with 1 GB RAM, run Home Assistant alone first; add Nextcloud only after HA is stable.

**1. Create config directory**

On the Pi:

```bash
mkdir -p ~/homeassistant/config
```

**2. Create `compose.yaml`**

Create `~/homeassistant/compose.yaml`:

```yaml
services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    volumes:
      - ./config:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    restart: unless-stopped
    stop_grace_period: 60s
    privileged: true
    network_mode: host
    environment:
      TZ: Europe/Warsaw
```

- `network_mode: host` — required for mDNS and local device discovery
- `privileged: true` — needed for USB serial adapters (Zigbee/Z-Wave)
- `/run/dbus` — optional; required for the Bluetooth integration
- `stop_grace_period: 60s` — lets SQLite shut down cleanly on restart

**3. Start**

```bash
cd ~/homeassistant
docker compose up -d
```

First boot can take several minutes on a Pi 3B. Watch logs:

```bash
docker compose logs -f homeassistant
```

**4. Open the UI**

Home Assistant listens on port **8123**.

| From | URL |
| --- | --- |
| LAN | `http://<pi-ip>:8123` or `http://raspberrypi.local:8123` |
| Tailscale | `http://raspberrypi.<tailnet>.ts.net:8123` |

Complete [onboarding](https://www.home-assistant.io/getting-started/onboarding/) in the browser.

**USB Zigbee / Z-Wave dongle (optional)**

Find the device on the Pi:

```bash
ls -l /dev/serial/by-id/
```

Add to `compose.yaml` under the service:

```yaml
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0
```

Use the path from `by-id` if possible. Add your user to the `dialout` group: `sudo usermod -aG dialout $USER` (reconnect SSH afterward).

**Updates**

```bash
cd ~/homeassistant
docker compose pull
docker compose up -d
```

**Troubleshooting**

- **Slow or OOM on Pi 3B** — check `free -h`; consider enabling swap or running fewer integrations
- **`Unsupported system page size`** — add `DISABLE_JEMALLOC: "true"` under `environment` in `compose.yaml`
- **UI won't load** — confirm the container is running: `docker compose ps`; wait for first-boot setup to finish

## Devices

Smart home devices integrated via [Home Assistant](#home-assistant). The fan and Pi must be on the same LAN — local control uses the fan's Wi‑Fi IP, not the cloud.

### Xiaomi Smart Tower Fan 2

| | |
| --- | --- |
| **Product** | Xiaomi Smart Tower Fan 2 |
| **Model** | `xiaomi.fan.p45` |
| **SKU** | BHR8846EU |

The built-in [Xiaomi Miio](https://www.home-assistant.io/integrations/xiaomi_miio/) integration does **not** support this model. Use the community [syssi/xiaomi_fan](https://github.com/syssi/xiaomi_fan) custom component instead (`xiaomi.fan.p45` support merged mid-2026).

Requires Home Assistant (see [Home Assistant](#home-assistant) above). On Home Assistant Container, install [HACS](https://hacs.xyz/docs/setup/download) first if you don't have it yet.

**1. Get the fan's IP and token**

1. Add the fan to the **Xiaomi Home** app and connect it to your Wi‑Fi
2. On your Mac, from this repo:

```bash
cd tools/xiaomi-cloud-tokens-extractor
./install.sh    # once
./run.sh
```

3. Log in (Xiaomi account password or QR code)
4. Select server region when prompted — `de` for EU
5. In the device list, find the Tower Fan 2 and copy its **IP address** and **token** (32 characters)

See [Xiaomi Cloud Tokens Extractor](#xiaomi-cloud-tokens-extractor) for details.

Store the token in `~/homeassistant/config/secrets.yaml` on the Pi:

```yaml
tower_fan_token: YOUR_32_CHAR_TOKEN
```

**2. Install the custom component**

Via HACS (recommended):

1. Open Home Assistant → **HACS** → **Integrations**
2. Search for **Xiaomi Mi Smart Pedestal Fan Integration** and install
3. Restart Home Assistant

Manual install (if HACS is not set up):

```bash
cd ~/homeassistant/config/custom_components
git clone https://github.com/syssi/xiaomi_fan.git /tmp/xiaomi_fan
cp -r /tmp/xiaomi_fan/custom_components/xiaomi_miio_fan .
cd ~/homeassistant && docker compose restart
```

**3. Configure**

Add to `~/homeassistant/config/configuration.yaml`:

```yaml
fan:
  - platform: xiaomi_miio_fan
    name: Tower Fan 2
    host: 192.168.X.X          # IP from token extractor output
    token: !secret tower_fan_token
    model: xiaomi.fan.p45      # required — do not omit
```

The `model:` line is required. Without it the integration won't use the correct profile. Some devices report `dmaker.fan.p45` in logs — configure as `xiaomi.fan.p45`.

Restart Home Assistant:

```bash
cd ~/homeassistant && docker compose restart
```

The fan appears as `fan.tower_fan_2` (entity ID derived from the name).

**4. Controls**

From the Home Assistant UI:

- Power on/off
- Speed (1–100%)
- Preset modes (Level 1–4, Natural 1–4, Sleep)
- Oscillation on/off

Extra options (child lock, LED, buzzer, swing angle, off-delay timer) use [platform services](https://github.com/syssi/xiaomi_fan#platform-services) — e.g. in **Developer tools** → **Actions**:

```yaml
action: xiaomi_miio_fan.fan_set_oscillation_angle
target:
  entity_id: fan.tower_fan_2
data:
  angle: 90
```

Swing angles: 30, 60, 90, 120, 150 degrees.

**Troubleshooting**

- **`Unsupported device found! ... dmaker.fan.p45`** — set `model: xiaomi.fan.p45` in `configuration.yaml` and update the custom component to the latest `syssi/xiaomi_fan` release
- **Entity unavailable** — confirm the fan IP hasn't changed (DHCP reservation recommended); verify the token is correct
- **Integration missing after restart** — check `~/homeassistant/config/custom_components/xiaomi_miio_fan/` exists and review logs: `docker compose logs homeassistant`

### Xiaomi Cloud Tokens Extractor

Retrieves API tokens and LAN IPs for Xiaomi cloud devices. Needed for the Tower Fan 2 — the built-in Home Assistant Xiaomi Miio integration cannot discover tokens on its own.

Upstream: [PiotrMachowski/Xiaomi-cloud-tokens-extractor](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor). Wrapped in this repo at `tools/xiaomi-cloud-tokens-extractor/` (scripts + venv; upstream code downloaded to gitignored `app/` on install).

Run on your **Mac** — QR-code login works best in a local terminal. Requires Python 3.

**Install** (once)

```bash
cd tools/xiaomi-cloud-tokens-extractor
./install.sh
```

Downloads the latest upstream release and creates `.venv/`.

**Run**

```bash
./run.sh
```

1. Choose login method — username/password or QR code (scan with Xiaomi Home app)
2. Enter server region — `de` for EU, or leave empty to search all regions
3. Browse the printed device list — each entry shows name, model, IP, and token

Copy the **IP** and **token** for your fan into Home Assistant config (see [Xiaomi Smart Tower Fan 2](#xiaomi-smart-tower-fan-2) above).

**Update**

```bash
rm -rf app .venv
./install.sh
```

**Troubleshooting**

If login fails, see [upstream troubleshooting](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor#troubleshooting):

- Use QR code instead of password
- Disable DNS ad blockers (AdGuard, Pi-hole) temporarily
- Check spam folder for 2FA email
- Xiaomi limits 2FA requests to a few per day per region

More detail: [tools/xiaomi-cloud-tokens-extractor/README.md](tools/xiaomi-cloud-tokens-extractor/README.md).

## Plans

- [Nextcloud](https://nextcloud.com/)
- [PostgreSQL](https://www.postgresql.org/) — in Docker, as the database for Nextcloud (and other services later)
