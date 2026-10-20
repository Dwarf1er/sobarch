+++
title = "Backing Up /home"
description = "A short restic recipe for backing up your home directory to an external drive."
weight = 35
template = "docs/page.html"

[extra]
lead = "Snapshots protect the system, not your files. A backup on a separate drive is what survives a dead disk or an accidental delete."
toc = true
+++

Sobarch's [snapshots](../../installer/snapshots/) cover the root
filesystem only, and they live on the same disk as your data. `/home` has
no snapshots and no backup unless you set one up. This page uses
[restic](https://restic.net/), which stores encrypted, deduplicated
backups, so each run after the first copies only what changed.

```sh
sudo pacman -S restic
```

## Set up a repository

Plug in the drive; it mounts under `/run/media/$USER/<label>`. Create a
repository on it and choose a password:

```sh
export RESTIC_REPOSITORY=/run/media/$USER/BACKUP/restic
restic init
```

**Keep the password somewhere safe, outside this machine.** The backup
is encrypted with it and cannot be recovered without it.

## Back up

```sh
restic backup ~ --exclude-caches --exclude ~/.cache
```

Run it whenever you like. Later runs only upload changes and take
seconds when little has changed. To avoid typing the password each time,
put it in a file readable only by you and set
`RESTIC_PASSWORD_FILE=~/.config/restic-password`.

## Look inside and restore

```sh
restic snapshots                                  # list backups
restic ls latest | less                           # files in the newest one
restic restore latest --target ~/restored --include /home/you/Documents
```

Restore into a new folder like `~/restored` and copy back what you need,
rather than restoring over your live files.

## Keep it tidy

Drop old snapshots and reclaim space, keeping a week of dailies, a month
of weeklies, and half a year of monthlies:

```sh
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
restic check
```

`restic check` verifies the repository; run it now and then.

## Notes

- A backup only on a drive that stays plugged in next to the computer
  doesn't protect against theft or fire. Keep a second copy elsewhere
  if the data matters. restic can also write straight to cloud storage;
  see its [documentation](https://restic.readthedocs.io/).
- There is no automatic schedule. You can run the backup command from a
  systemd user timer if you want one.
- [borg](https://www.borgbackup.org/) does the same job and is a fine
  alternative if you already use it.
