# terabox-link

One command turns any Linux VPS's TeraBox cloud storage (1 TB free) into the VPS's own disk.

## Install

Log in to your VPS as root and run:

```bash
curl -fsSL https://raw.githubusercontent.com/ItzJoker2YT-city/mini-core/main/terabox-link/install.sh | bash
```

It asks you to paste your TeraBox login key (see "Getting your key" below), then sets everything up and runs a self-test.

Non-interactive version:

```bash
curl -fsSL https://raw.githubusercontent.com/ItzJoker2YT-city/mini-core/main/terabox-link/install.sh | bash -s -- --cookie "ndus=...; csrfToken=...; ..."
```

## What you get

- `/root/disk` â€” put files here and they auto-upload to your TeraBox (folder `disk`) within ~30 seconds. The local copy is cleared after upload so a small VPS disk never fills up.
- `tb` â€” list everything on your TeraBox
- `tbsync` â€” force-upload the disk folder right now
- `tbpull NAME` â€” download a file back from TeraBox (saved to `/root/pulled/`)
- `rclone` with a ready `terabox:` remote for anything else (`rclone copy /root/file.txt terabox:`)

Files appear on terabox.com / the TeraBox app instantly.

## Getting your key (the login)

1. Open https://www.terabox.com on a computer and log in.
2. Press **F12** â†’ open the **Network** tab â†’ refresh the page (**F5**).
3. Click the very first request in the list (the top row).
4. Under **Request Headers**, find the line starting with `Cookie:`.
5. Copy the whole long value after `Cookie:` and paste it into the installer.

The key is stored only on your VPS in a root-only file (`/root/.terabox-cookie`, chmod 600).

## Requirements

- Root on Debian / Ubuntu / Alpine / Fedora / Arch (x86_64 or arm64)
- Internet access (the installer downloads rclone + [OpenList](https://github.com/OpenListTeam/OpenList) â‰ˆ 30 MB)

## How it works

```
VPS                                TeraBox cloud
/root/disk â”€â”€(auto every ~20s)â”€â”€â–º  rclone â”€â”€WebDAVâ”€â”€â–º OpenList bridge
                              (localhost:5244)  â”€â”€â–º  TeraBox API
```

The bridge listens on `127.0.0.1` only â€” nothing is exposed to the internet. Your TeraBox login key stays on the VPS. Re-running the installer is safe: it refreshes the key and re-links without touching your files.

If uploads ever stop working weeks later, the key expired â€” just run the installer again with a fresh key.

## Notes

- TeraBox caps upload speed around 3 MB/s per file.
- For files over ~1 GB add `--timeout 0`: `rclone copy --timeout 0 bigfile.zip terabox:`
- Uninstall: delete `/root/bin /root/openlist /root/.terabox-cookie /root/.tb-admin-pass /root/.tb-webdav-pass`, remove the block starting with `# --- TeraBox disk` from `/root/.bashrc` (original is at `/root/.bashrc.tb-backup`), and `pkill -f tb-sync.sh; pkill -f openlist`.
