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
