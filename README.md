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

## Contributing a configuration

1. Fork this repository on GitHub, then clone your fork locally:

   ```sh
   git clone https://github.com/YOUR-USER/cdtv-pistorm-configs.git
   cd cdtv-pistorm-configs
   ```

2. Create a branch for the configuration you are submitting:

   ```sh
   git switch -c your-user/cdtv-build46
   ```

3. Mount or locate a complete Emu68 FAT boot tree. This may be an SD-card boot partition such as `/Volumes/EMU68`, or a backup folder containing `CONFIG.TXT` and `Boot/CMDLINE.TXT`.

4. Capture the active configuration. `CDTV` is the default machine; use `--machine A570` or `--machine A690` where appropriate:

   ```sh
   ./scripts/capture-boot-volume.sh /Volumes/EMU68 your-user my-config
   ```

   The command creates a draft beneath `profiles/drafts/`. It reads the source tree only, copies the text configuration snapshots, and records SHA-256 fingerprints for the one selected kernel, active `initramfs` files, and enabled overlays. It does not copy ROMs, kernels, or other binary payloads.

5. Move the draft to your contributor directory and complete the test result fields in `profile.yaml`:

   ```sh
   mkdir -p profiles/your-user
   mv profiles/drafts/your-user-my-config profiles/your-user/my-config
   ./scripts/validate-registry.sh
   ```

6. Commit and push your branch, then open a pull request to this repository's `main` branch:

   ```sh
   git add profiles/your-user
   git commit -m "Add your-user CDTV configuration"
   git push -u origin your-user/cdtv-build46
   ```

Maintainers review the configuration for reproducibility and confirm that it contains no prohibited binary files before merging it into the shared registry.

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
./scripts/verify-profile-files.sh profiles/chris/cos-beta1-build46-a1200-single-kernel/profile.yaml /Volumes/EMU68
```

## Restore a profile

The restore helper reconstructs a profile from files already available in a local source tree. It never downloads ROMs or binaries. SHA-256 is the artifact identity: source filenames may differ from the filenames in the profile, provided their bytes match.

Verify-only mode is the default:

```sh
./scripts/restore-profile.sh \
  profiles/chris/cos-beta1-build46-a1200-single-kernel/profile.yaml \
  /path/to/local-boot-file-library \
  /Volumes/EMU68
```

It searches the source tree for every fingerprinted kernel, initramfs asset, and overlay by SHA-256 before printing the planned replacements. It does not modify the destination in this mode.

To restore, add `--commit`. The script asks for `Y/N` confirmation, saves every destination file it would replace to a timestamped backup outside the destination tree, restores assets first, then `CONFIG.TXT` and `Boot/CMDLINE.TXT`, and verifies copied SHA-256 values afterward:

```sh
./scripts/restore-profile.sh \
  profiles/chris/cos-beta1-build46-a1200-single-kernel/profile.yaml \
  /path/to/local-boot-file-library \
  /Volumes/EMU68 \
  --commit
```

The helper refuses a profile whose `config.txt` snapshot has zero or multiple active `kernel=` statements. It cannot restore AmigaDOS-partition files such as `VideoCore.card`; those require a separate Amiga filesystem workflow.
