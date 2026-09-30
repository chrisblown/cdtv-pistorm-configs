# PiStorm CDTV configuration registry

This repository records reproducible PiStorm/Emu68 CDTV boot configurations.

It deliberately stores configuration text, file names, byte sizes, and SHA-256 fingerprints—but never ROM images, Kickstarts, disk images, or other binary payloads.

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

4. Capture the active configuration:

   ```sh
   ./scripts/capture-boot-volume.sh /Volumes/EMU68 your-user my-config
   ```

   This creates a draft under `profiles/drafts/`; see the script reference below for options and constraints.

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

## Script reference

All scripts are POSIX shell and run locally. None downloads ROMs, kernels, or other boot binaries.

### `capture-boot-volume.sh`

```sh
./scripts/capture-boot-volume.sh SOURCE_TREE AUTHOR PROFILE_ID \
  [--machine CDTV|A570|A690] \
  [--pistorm-type classic|pistorm16|pistorm32lite|pistorm32lite-stealth] \
  [--initramfs comma,separated,paths]
```

Reads `SOURCE_TREE` only and creates `profiles/drafts/AUTHOR-PROFILE_ID/`. The source may be a mounted FAT boot partition, such as `/Volumes/EMU68`, or a local backup containing readable `CONFIG.TXT` and `Boot/CMDLINE.TXT`. It copies those text snapshots and fingerprints the effective kernel, initramfs assets, and overlays. It accepts LF or CRLF configuration files and resolves FAT asset paths regardless of directory case.

`classic` is the default PiStorm type. When a config has multiple `initramfs` lines and no `--pistorm-type`, the script asks whether to use Classic; answer `n` to exit and rerun with an explicit type. The type selects the corresponding GPIO section in a stock CaffeineOS config: Classic uses `[gpio17=0]`, PiStorm16 `[gpio24=1]`, PiStorm32 Lite `[gpio24=0]`, and PiStorm32 Lite Stealth `[gpio4=0]`. Use `--initramfs` only to override an unusual configuration explicitly.

### `validate-registry.sh`

```sh
./scripts/validate-registry.sh
```

Checks every committed or draft profile for schema version 1, well-formed SHA-256 entries, a readable `config.txt` snapshot with exactly one `kernel=` statement, and prohibited binary files in the repository. Run it before committing. It validates registry structure; it does not verify that your local ROM library contains the recorded files.

### `verify-profile-files.sh`

```sh
./scripts/verify-profile-files.sh PROFILE.yaml SOURCE_TREE
```

Read-only check. It recursively searches only `SOURCE_TREE` and its subdirectories for a file matching each profile SHA-256, then reports the matching local path. Filenames and case do not have to match the profile: identical bytes are sufficient. This is useful before a restore or when comparing a backup against a profile.

### `restore-profile.sh`

```sh
./scripts/restore-profile.sh PROFILE.yaml SOURCE_TREE DESTINATION_TREE \
  [--commit|-commit] [--backup-dir /absolute/path]
```

`SOURCE_TREE` and `DESTINATION_TREE` must be different absolute paths. By default this is verify-only: it recursively searches only the supplied source tree by SHA-256, lists all target paths it would replace, and changes nothing. With `--commit`, it requests a `Y/N` confirmation, backs up each replaced boot asset plus `CONFIG.TXT` and `Boot/CMDLINE.TXT`, restores the matched assets under the profile's required filenames, then post-verifies their hashes. The default backup location is a timestamped directory beneath `backups/`; use `--backup-dir` to choose another absolute location outside the destination tree.

The restore script operates only on the FAT boot partition. It cannot install files on the AmigaDOS partition, including `LIBS:Picasso96/VideoCore.card`.
