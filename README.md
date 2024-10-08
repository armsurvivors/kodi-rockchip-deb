### Warning: vendor/legacy/bsp kernel stuff

- for Rockchip rk35xx devices that support rkmpp and rkrga
- Requires either:
    - Armbian rk35xx vendor kernel (6.1-rkr3, 6.1.75, which includes panthor backport and requires 24.1+ mesa)
    - Armbian rk35xx legacy kernel (5.10-rkr8, 5.10.290, which requires mali blobs/panfork)

### kodi-rockchip-deb

> mainline Kodi for rk35xx hwaccel Rockchip's MPP and RGA via ffmpeg-rockchip, via boogie/nyanmisaka/joshua/amazingfate magic; rk bsp/vendor/legacy kernel required.

#### Features

- mainline Kodi
    - including boogie's https://github.com/xbmc/xbmc/pull/24431
- ffmpeg-rockchip from nyanmisaka
- fully accelerated (`GBM`+`rkmpp`+`rkrga`+`AFBC`), see https://github.com/nyanmisaka/ffmpeg-rockchip/wiki/Rendering#kodi-under-gbm
    - > _This type of rendering is the fastest method you can get. To run kodi with gbm support, the active Desktop Environment must be stopped so that Kodi can directly interact with KMS_
- works with both Legacy and Vendor kernels

### Install

- Flash an Armbian CLI image for your board (`jammy`, `noble`, `bookworm`, or `trixie` for now)
    - Alternatively, you can use an Armbian desktop image, but GDM3/SDDM/LightDM will be disabled and Kodi will take over
    - For CLI images, you still need the mesa/panfrost/panthr (for vendor `6.1-rkr3`) or mail/panfork (for `5.10-rkrX`) stack
- Download the .deb from the [releases page](https://github.com/armsurvivors/kodi-rockchip-deb/releases), apprpriate for your Armbian distro (`jammy`, `noble`, `bookworm`, or `trixie`)
- From an SSH or console connection (not in X11 or Wayland),
    - ✅ install with `apt install ./kodi-rockchip-gbm*.deb`
    - ❌ `dpkg -i` won't work as it doesn't pull dependencies
    - ℹ️ during install, it will disable your display manager if you have one running
- Start the service with `sudo systemctl start kodi`
    - `kodi` service uses ALSA directly, look around for the PulseAudio version (`kodi-pulse`) if you prefer that

### Troubleshooting

- If converting a desktop image, you might need to reboot to cleanup display server usage.
- Tested on rk3588, other rk35xx untested; try and report back.

## TO-DO

- [ ] Don't run as root
- [ ] Don't expose Pulseaudio to the network
- [ ] Fix MCE Remote OK/Back buttons (is it 2011 again?)

## Building

- This is built in a Docker container
- Look at the GHA workflow for the steps
- Definitely requires `docker buildx` / `BuildKit`
- Output is an Alpine image containing the built .deb
- Can only be built _on_ arm64 - no cross-compilation
