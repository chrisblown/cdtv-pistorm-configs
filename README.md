# PiStorm CDTV configuration registry

This repository records reproducible PiStorm/Emu68 CDTV boot configurations.

It deliberately stores configuration text, file names, byte sizes, and SHA-256 fingerprints—but never ROM images, Kickstarts, disk images, or other binary payloads.

## Capture a boot tree

The source can be either a mounted FAT boot partition or a local backup of one. It must contain `CONFIG.TXT` and `Boot/CMDLINE.TXT`.

For a mounted card:

```sh
./scripts/capture-boot-volume.sh /Volumes/EMU68 chris
```

For a backup folder:

```sh
./scripts/capture-boot-volume.sh /path/to/EMU68-backup chris backup-2026-09-22
```

The command reads the supplied boot tree, creates a draft profile under `profiles/drafts/`, copies `CONFIG.TXT` and `Boot/CMDLINE.TXT` as text snapshots, and fingerprints relevant files. It never writes to the supplied source folder.

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
