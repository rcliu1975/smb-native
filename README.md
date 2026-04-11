# smb-native

Use the host OS Samba service directly, without Docker, to expose a password-protected SMB share.

## What It Does

- Installs the Debian/Armbian `samba` package
- Creates or reuses a Unix account as the SMB login
- Creates a writable share directory
- Writes `/etc/samba/smb.conf` from the repo template
- Adds the Samba password for the chosen user
- Enables and restarts `smbd` and `nmbd`

## Files

- `install-samba.sh`: install and configure Samba
- `status-samba.sh`: inspect the running Samba service and current share config
- `smb.conf.template`: Samba config template applied by the installer

## Requirements

- Debian 13 / Armbian or another `apt-get` based system
- `sudo` access
- An existing Unix user for SMB login

## Quick Start

```bash
cd smb-native
sudo ./install-samba.sh
```

The installer will prompt for the Samba password without echoing it.

Default values:

- `SMB_USER=<the non-root user who ran sudo>`
- `SHARE_NAME=<same as SMB_USER>`
- `SHARE_DIR=<that user's home directory>`
- `WORKGROUP=WORKGROUP`

The installer derives the share name and home directory from the account that invoked `sudo`.

## Check Status

```bash
./status-samba.sh
```

## Connect

After install, connect with:

- Windows: `\\<host-ip>\<username>`
- macOS/Linux: `smb://<host-ip>/<username>`

## Notes

- The installer backs up the previous `/etc/samba/smb.conf` before replacing it.
- `install-samba.sh` must run as root.
- Password entry is interactive by design, so real passwords do not need to be passed through environment variables or on the command line.
- Firewall rules are not managed by this repo.
