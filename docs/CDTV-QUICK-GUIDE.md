# CDTV PiStorm and Emu68 quick guide

This guide describes a practical starting point for running a **classic (DIP-64) PiStorm** in a Commodore CDTV with Emu68. It combines the official PiStorm and Emu68 procedures with configurations tested on a CD1000.

Last checked: **26 November 2026**. The current Emu68 pre-release used here is **Emu68 1.1 beta.1**. Always read the release notes before replacing a working installation.

> **CDTV support is still experimental.** Back up the entire SD card before changing its partition table, CPLD firmware, boot files, ROMs, or CaffeineOS installation. Initially test without a rear SCSI card fitted.

## Two different updates

PiStorm has two independently updated parts:

1. **PiStorm CPLD firmware** controls the physical Amiga bus. The CDTV requires a CDTV-compatible experimental build with bus arbitration support.
2. **Emu68 and Raspberry Pi boot files** live on the FAT boot partition of the SD card. They are installed by copying files, not by programming the CPLD.

Updating Emu68 does not automatically make an old CPLD bitstream CDTV-compatible. Conversely, flashing the CPLD does not update Emu68 on the SD card.

## What you need

- A working CDTV, tested with its original 68000 if possible.
- A classic PiStorm and supported Raspberry Pi, normally a Pi 3A+ or Pi Zero 2.
- A good-quality SD card and a full backup of it.
- The latest dedicated **PiStorm CDTV beta release**, including its bus-arbitration CPLD firmware. The beta setup used here contains `EPM240_pistorm-bgsync.svf.gz` for an EPM240 classic PiStorm.
- [`Emu68-pistorm-classic.zip` from the Emu68 1.1 beta.1 release](https://github.com/michalsc/Emu68/releases/tag/v1.1.0-beta.1). Do not use `Emu68-pistorm.zip` or `Emu68-raspi.zip` for the classic CPLD PiStorm.
- A legally obtained Kickstart ROM.
- A compatible CDTV extended ROM if CDTV CD-ROM functions are required.
- For CaffeineOS 93.17, `VideoCore.card` **1.5** from the same Emu68 release. This is required, not an optional RTG extra.

## 1. Install the dedicated CDTV CPLD beta

Use the CPLD firmware from the **CDTV beta release**, not the normal firmware from the generic `captain-amygdala/pistorm` repository. In particular, do not run the generic repository's plain `./flash.sh` as part of this guide: it may replace the CDTV bus-arbitration firmware with the normal bitstream and leave the CD-ROM unusable.

The CDTV beta setup tested here contains:

```text
EPM240_pistorm-bgsync.svf.gz
```

That name identifies the bus-grant-synchronised EPM240 image used by the tested classic PiStorm. It must not be assumed suitable for a different CPLD. Confirm the chip fitted to your PiStorm and use the matching image supplied in the latest CDTV beta package.

Emu68 accepts both gzip-compressed and uncompressed `initramfs` payloads. For the known EPM240 CDTV beta package, the supplied firmware is compressed and its one-time flashing selection is:

```ini
initramfs EPM240_pistorm-bgsync.svf.gz
```

Use this only when it matches the instructions and CPLD image in your CDTV beta release:

1. Back up the working FAT boot volume and its current `config.txt`.
2. Copy the CDTV beta's supplied `.svf.gz` or uncompressed `.svf` file to the FAT volume and use that exact filename in `initramfs`.
3. Temporarily comment out the normal ROM `initramfs` and leave the firmware line above as the only active `initramfs`.
4. Boot and allow the firmware programming operation to finish. Do not interrupt power while it is writing.
5. Power off, remove or comment the firmware line, and restore the normal extended-ROM/Kickstart `initramfs` before the next normal boot.

If the current CDTV beta release provides a different filename or flashing procedure, its release instructions take precedence. Record the beta version, CPLD type, firmware filename, size, and SHA-256.

If your PiStorm already has the latest confirmed CDTV bus-arbitration beta, do not reflash it merely to update Emu68. Update only the SD boot files in the next section so the CPLD and Emu68 changes remain separate.

## 2. Prepare or back up the SD card

The usual Emu68 layout is:

- partition 1: FAT32 boot volume containing Raspberry Pi and Emu68 files;
- partition 2: MBR partition type `0x76`, containing the Amiga RDB and Amiga partitions.

The official [Emu68 SD preparation guide](https://github.com/michalsc/Emu68/blob/master/docs/tutorials/SD_Preparation.md) explains creating this layout. If you already have CaffeineOS, keep its partition table and Amiga partition intact—update only the files on the FAT volume.

Before changing anything, make a raw image of the complete SD card or otherwise back up both partitions. A copy of the visible FAT files alone is not a complete CaffeineOS backup.

Extract `Emu68-pistorm-classic.zip` and copy its complete contents to the root of the FAT boot partition. Preserve the archive's directory structure. The supplied beta kernel is gzip-compressed:

```text
Emu68-pistorm-classic.gz
```

Emu68 supports both this compressed kernel and an uncompressed image. The CDTV configuration tested here uses the uncompressed form because it produced fewer intermittent black screens during startup:

```sh
mkdir -p kernel
gzip -dc Emu68-pistorm-classic.gz > kernel/Emu68.img
```

You can also extract it with a graphical archive utility and rename the result. Both layouts are valid, but `kernel=` in `config.txt` must match the selected file's path and name exactly. For a new CDTV setup, this guide recommends the tested uncompressed `kernel/Emu68.img`; keep the original `.gz` file available for comparison.

## 3. Prepare the ROM files

Create a directory such as `roms` on the FAT partition and add your legally obtained ROM files.

For the CDTV, the `initramfs` list loads the extended ROM first and the main Kickstart second:

```text
initramfs roms/cdtv236.rom,roms/kick.rom
```

CDTV OS extended ROM releases are commonly distributed as a 256 KiB CD1000 image. The tested Emu68 arrangement uses a **512 KiB file made by zero-padding the 256 KiB image**, not by duplicating it. Preserve the raw file and create a separate padded copy:

```sh
cp cdtv236-raw.rom cdtv236.rom
truncate -s 512K cdtv236.rom
```

Confirm the result is 524,288 bytes. Padding changes its SHA-256, so record hashes for both the raw source and the boot-ready copy.

```sh
# macOS
shasum -a 256 cdtv236.rom

# Linux
sha256sum cdtv236.rom

# Windows PowerShell
Get-FileHash .\cdtv236.rom -Algorithm SHA256
```

ROM filenames are only labels; SHA-256 and byte size identify the actual content.

As with the firmware payload, Emu68 can consume gzip-compressed or uncompressed files through `initramfs`. The tested CDTV ROM setup uses uncompressed, 512 KiB ROM files. Use the exact filenames present on the FAT volume and do not mix a compressed file's SHA-256 with its uncompressed form.

## 4. Configure Emu68 1.1 beta.1

Emu68 1.1 moves most options from the one-line `cmdline.txt` into device-tree overlays in `config.txt`. Begin with the `config.txt` shipped in the beta archive, then add the CDTV ROM selection and SD overlays.

A compact classic-PiStorm example is:

```ini
kernel=kernel/Emu68.img

disable_splash=1
arm_64bit=1
boot_delay=1
avoid_warnings=2

hdmi_force_hotplug=1

dtoverlay=sdhc,unit0=rw,clock=75
dtoverlay=z2ram,size=0

initramfs roms/cdtv236.rom,roms/kick.rom
```

Notes:

- `sdhc` is the SD driver overlay for Pi 3 and Pi Zero 2. `unit0=rw` exposes the whole SD card as writable unit 0; use `ro` or `off` if that access is not needed.
- The uncompressed kernel is recommended for this CDTV guide because it gave fewer black-screen starts in testing. The supplied `.gz` kernel remains supported and can be selected by changing `kernel=` to its exact path.
- `clock=75` is the setting used by the tested configuration. Remove it and use the default speed if the SD card is unreliable.
- `z2ram,size=0` disables Zorro II Fast RAM; Emu68 can still provide other memory.
- Keep exactly one active `kernel=` and one active `initramfs` for a simple CDTV setup. Commented alternatives are harmless, but a clean file is easier to diagnose.
- Do not add GPIO-selected kernels intended for several PiStorm models when building a dedicated CDTV card.
- Leave overclocking disabled until the machine is stable.

### `cmdline.txt`

With Emu68 1.1, prefer overlays for settings supported by the supplied `.dtbo` files. If an existing image uses a separate command line, `config.txt` may contain:

```ini
cmdline=boot/cmdline.txt
```

The referenced file must contain **one line only**. The configuration tested in this repository used:

```text
z2_ram_size=0 vc4.mem=64 sd.clock=75 sd.unit0=rw fast_page_zero
```

The equivalent `z2ram` and `sdhc` overlay settings should be preferred in a new beta-1 installation. In our CDTV testing, `fast_page_zero` made the otherwise missing FPU appear, but it also made the 1 MiB CDTV falsely register 2 MiB of Chip RAM. [Emu68 issue #343](https://github.com/michalsc/Emu68/issues/343) documents the Chip RAM detection fault.

Treat `fast_page_zero` only as a temporary diagnostic workaround. The Emu68 author plans to remove the option, so profiles that depend on it are not future-proof. CDTV Land is investigating an Emu68 CDTV-specific patch intended to retain correct FPU behaviour without corrupting Chip RAM detection. Until that work is available and tested, the choice is currently between correct 1 MiB Chip RAM detection without the workaround and FPU visibility with an incorrect 2 MiB report.

The Emu68 1.1 overlay documentation included in the archive describes options such as `dtoverlay=emu68,FP0`; `FP0` has the same first-4-KiB mapping concern on machines with less than 2 MiB of physical Chip RAM.

## 5. First boot

1. Remove any rear SCSI card for the first test.
2. Insert the SD card and power on the CDTV.
3. Confirm the Emu68/PiStorm screen appears once and the machine continues to the CDTV or Kickstart screen. A repeating Emu68 screen/black-screen cycle usually means a ROM combination, path, file-size, or CPLD/Emu68 compatibility problem.
4. Test in this order, changing one item at a time:
   - cold and warm boot;
   - correct Kickstart and CDTV OS versions;
   - expected Chip and Fast RAM;
   - FPU visibility;
   - data CD boot and file access;
   - audio CD;
   - CD+G;
   - rear SCSI card last.
5. Wait for all disk activity to finish before removing power.

## Optional: use CaffeineOS (`VideoCore.card` is required)

CaffeineOS itself is optional, but `VideoCore.card` is not optional when using CaffeineOS 93.17 with Emu68 1.1 beta.1. CaffeineOS can remain on the Amiga partition while the FAT boot files, Emu68 kernel, and ROM selection are updated independently.

1. Back up the whole CaffeineOS SD card.
2. Update the FAT boot partition using the steps above. Do not format or recreate the `0x76` partition.
3. **Required:** install `VideoCore.card` 1.5 on the Amiga volume as:

   ```text
   LIBS:Picasso96/VideoCore.card
   ```

   CaffeineOS 93.17 requires the VideoCore driver, and Emu68 1.1 beta.1 requires driver version 1.5. Version 1.5 is not compatible with Emu68 1.0. Because macOS does not normally mount the Amiga filesystem, copy it from a real Amiga or attach the Amiga partition as a secondary drive in Amiberry/WinUAE. Back up the existing card file first.

4. Boot CaffeineOS and verify the selected Picasso96 screen mode, FPU, CD access, and resident/device versions.

### `mathffp-patch` failure

Some CaffeineOS 93.17 combinations fail during startup at `mathffp-patch`. To test without the patch, edit `S:Startup-Sequence`, find the line that invokes it, and comment that command with the AmigaDOS comment character:

```text
; mathffp-patch
```

Do **not** use `#`; it is not the normal AmigaDOS startup-script comment character and can break the startup sequence. This workaround only disables the failing patch—it does not establish why that ROM combination rejects it.

## A configuration known to boot

The repository's [`latest-beta-stable` profile](../profiles/chris/latest-beta-stable/profile.yaml) records this tested combination:

- classic PiStorm in a CDTV;
- Emu68 1.1 beta.1;
- CDTV OS 2.36 build 51 RC CD1000 extended ROM, zero-padded to 512 KiB;
- Kickstart 3.2.3 A1200 version 47.115;
- CaffeineOS 93.17;
- boot and FPU confirmed.

In that test the FPU appeared only after enabling `fast_page_zero`, and the system then incorrectly reported 2 MiB Chip RAM. This is the known workaround and side effect described above—not proof of 2 MiB physical Chip RAM or a final stable solution. The option is expected to be removed, while a CDTV-specific Emu68 patch is being investigated. CD, audio CD, CD+G, and rear-SCSI results remain unrecorded for that profile.

ROM and Kickstart files are not included in this repository. Use the profile's SHA-256 values to identify matching local files.

## Known CDTV limitation: rear SCSI cards

On the tested CDTV, two rear SCSI cards of the same design work with a real 68000 but are not usable with the current PiStorm beta. Drives do not appear, and CD-ROM activity with either card installed hard-locks the machine. CD-ROM access works without the rear SCSI card.

This points to an unresolved bus-arbitration/DMA interaction, not a proven ROM-only problem. Treat rear SCSI as unsupported until independently verified with the exact CPLD and Emu68 builds in use.

## Save a reproducible profile

From this repository, a mounted FAT boot volume can be captured without storing copyrighted binaries:

```sh
./scripts/capture-boot-volume.sh /Volumes/EMU68 your-name profile-id \
  --machine CDTV --pistorm-type classic
./scripts/validate-registry.sh
```

The profile stores paths, sizes, SHA-256 fingerprints, `config.txt`, `cmdline.txt`, and test results. It does not store ROMs or kernels.

## Primary references

- [Emu68 1.1 beta.1 release notes](https://github.com/michalsc/Emu68/releases/tag/v1.1.0-beta.1)
- [Official Emu68 SD preparation guide](https://github.com/michalsc/Emu68/blob/master/docs/tutorials/SD_Preparation.md)
- [Official Emu68 PiStorm `config.txt` example](https://github.com/michalsc/Emu68/blob/master/scripts/config_pistorm.txt)
- [PiStorm repository](https://github.com/captain-amygdala/pistorm)—general project background only; its normal flashing procedure is not the CDTV beta procedure used by this guide
