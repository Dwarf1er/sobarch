# Sobarch

A minimal, reproducible Arch Linux + Hyprland desktop setup: installer,
versioned configuration, and package tooling in one repo.

Sobarch started after managing a dotfiles repository that eventually grew into a pile of other scripts and features; OS-level tweaks, packages, configuration, installation, multi-machine hardware detection, etc. It came to a point where creating a small reproducible environment was less overhead than letting the dotfiles spaghetti grow. The goals are simple; minimalistic in all aspects, as close to upstream Arch as possible, no custom package repository, as little dependencies as possible and a minimal amount of custom tooling to help managing the project.

The distribution is primarily built for its maintainer, but it hopes to stay understandable and usable by others. The minimalistic approach and simplicity will hopefully be good enough as a base for others as well.


<!-- mtoc-start -->

* [Quickstart](#quickstart)
* [Installer](#installer)
* [Documentation](#documentation)
* [License](#license)

<!-- mtoc-end -->

## Quickstart

Not available yet.

**Note:** the installer currently only supports full-disk installs. It
partitions and wipes the entire target disk, and dual/multi-boot
(installing alongside an existing OS) is not supported.

## Installer

`installer/archinstall/base.json` and `credentials.json` are not valid
input to `archinstall` as-is. The TUI must perform a plain text
substitution pass before invoking `archinstall --config base.json
--creds credentials.json --silent`, replacing each of the following
tokens:

| Token | Found in | Notes |
|---|---|---|
| `__DISK_DEVICE__` | `base.json` | The target disk chosen in the TUI (e.g. `/dev/nvme0n1`). |
| `__ROOT_PARTITION_SIZE_BYTES__` | `base.json` | Must be replaced with a raw integer (remove the surrounding quotes too), not another quoted string. |
| `__HOSTNAME__` | `base.json` | |
| `__KB_LAYOUT__` | `base.json` | e.g. `us` |
| `__SYS_LANG__` | `base.json` | e.g. `en_US.UTF-8` |
| `__TIMEZONE__` | `base.json` | e.g. `America/Montreal` |
| `__USERNAME__` | `credentials.json` | |
| `__ENC_PASSWORD__` | `credentials.json` | Must be replaced with a raw string; quotes can stay since this one *is* a string field. |

## Documentation

## License

This software is licensed under the [MIT license](LICENSE)
