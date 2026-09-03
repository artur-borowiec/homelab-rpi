# homelab-rpi

Documentation for my Raspberry Pi homelab setup running a 64-bit OS.

## Hardware

- **Board:** Raspberry Pi 3 Model B

## Setup

### Flash OS to SD card

Used [Raspberry Pi Imager](https://www.raspberrypi.com/software/) on macOS to write the OS image to the SD card.

### Initial setup

- SSH access
- [Tailscale](https://tailscale.com/)

#### SSH access (macOS + 1Password)

SSH keys live in [1Password](https://developer.1password.com/docs/ssh/get-started). The private key never goes on disk — the 1Password SSH agent signs requests after you approve (e.g. Touch ID).

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
3. Add a temporary host entry to `~/.ssh/config`. The Pi does not have your key yet, so the first login must use the Pi user password. That sounds like plain `ssh pi@<pi-ip>`, but step 2 already pointed SSH at the 1Password agent — on connect, the agent tries every stored key before SSH falls back to a password. With several keys, the Pi rejects the attempts (`Too many authentication failures`) and you never get a password prompt. This block is a one-time bootstrap alias: it tells SSH to skip public keys and ask for the password only:

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

4. Copy the public key to the Pi:

```bash
ssh-copy-id -i ~/.ssh/homelab-rpi.pub password-auth-ssh
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

## Tools

- [CUPS](https://www.cups.org/) — print server
- [Docker](https://www.docker.com/)

## Docker

Application services run in Docker where it makes sense; system-level tools stay on the host.

### What runs in Docker

| Service | Docker? | Notes |
| --- | --- | --- |
| SSH | No | Host OS configuration |
| Tailscale | No | Install on the host for node-level VPN |
| CUPS | No | Needs direct USB/network printer access; native install is simpler |
| Home Assistant | Yes | Well supported via official container image |
| Nextcloud | Yes | Typical stack: Nextcloud + database (MariaDB/PostgreSQL) via Compose |

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
