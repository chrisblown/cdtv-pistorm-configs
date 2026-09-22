# PiStorm CDTV configuration registry

This repository records reproducible PiStorm/Emu68 CDTV boot configurations.

It deliberately stores configuration text, file names, byte sizes, and SHA-256 fingerprints—but never ROM images, Kickstarts, disk images, or other binary payloads.

## Capture a boot tree

The source can be either a mounted FAT boot partition or a local backup of one. It must contain `CONFIG.TXT` and `Boot/CMDLINE.TXT`.

For a mounted card:

```sh
./scripts/capture-boot-volume.sh /Volumes/EMU68 chris cos-current
```

For a backup folder:

```sh
./scripts/capture-boot-volume.sh /path/to/EMU68-backup chris backup-2026-09-22
```

The command reads the supplied boot tree, creates a draft profile under `profiles/drafts/`, copies `CONFIG.TXT` and `Boot/CMDLINE.TXT` as text snapshots, and fingerprints only the selected kernel, files named by `initramfs`, and enabled overlays. It never writes to the supplied source folder.

`CDTV` is the default machine. Use `--machine A570` or `--machine A690` for those targets.

For reproducibility, this registry accepts only one active `kernel=` statement in `CONFIG.TXT`. GPIO/multi-kernel configurations are rejected because a mounted volume or backup does not reveal which GPIO branch booted. The kernel filename itself is unrestricted. If a profile uses a conditional `initramfs` line, supply that value explicitly with `--initramfs`.

## Profile layout

Each submitted configuration is a directory:

```text
profiles/<contributor>/<profile-id>/
  profile.yaml
  config.txt
  cmdline.txt
```

The YAML describes hardware, the active boot configuration, fingerprints, and test results. The adjacent config files are exact captured snapshots.

## Submission rules

- Never commit ROMs, Kickstarts, kernels, `.img`, `.hdf`, `.adf`, or `.card` files.
- Do commit their SHA-256 values, byte sizes, release/source references, and any transformation such as zero-padding to 512 KiB.
- One profile represents one boot configuration. Add a new profile for a materially different test.
- Mark an untested capture as `pending`; record observed outcomes after hardware testing.

## Validate

```sh
./scripts/validate-registry.sh
```

To check that a local boot tree contains every fingerprinted active asset from a profile:

```sh
./scripts/verify-profile-files.sh profiles/chris/cos-beta1-build46-a1200/profile.yaml /Volumes/EMU68
```
