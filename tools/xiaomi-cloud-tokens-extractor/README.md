# Xiaomi Cloud Tokens Extractor

Local copy of [PiotrMachowski/Xiaomi-cloud-tokens-extractor](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor) for retrieving Xiaomi device API tokens (e.g. Tower Fan 2).

Run on your **Mac** (recommended — easier QR login) or on the Pi over SSH. Requires Python 3 and network access to Xiaomi cloud.

## Install

```bash
./install.sh
```

Downloads the latest upstream release into `app/` and creates a Python venv in `.venv/`.

## Run

```bash
./run.sh
```

Log in with Xiaomi account credentials or QR code, pick your server region (`de` for EU), then copy the **token** and **IP** for your fan from the device list.

## Reinstall / update

```bash
rm -rf app .venv
./install.sh
```
