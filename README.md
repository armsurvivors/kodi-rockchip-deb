### Warning: vendor/legacy/bsp kernel stuff

- for Rockchip rk35xx devices that support rkmpp and rkrga
- Requires either:
  - Armbian rk35xx vendor kernel (6.1-rkr3, 6.1.75, which includes panthor backport and requires 24.1+ mesa) 
  - Armbian rk35xx legacy kernel (5.10-rkr8, 5.10.290, which requires mali blobs/panfork)

### kodi-rockchip-deb

> Build Kodi with Rockchip's RKMPP and RKRGA via ffmpeg-rockchip in a Docker container and produce a huge .deb with all dependencies.

#### Features

- mainline Kodi
  - including boogie's https://github.com/xbmc/xbmc/pull/24431  
- ffmpeg-rockchip from nyanmisaka
- fully accelerated
- no black video ;-)
- works with both Legacy and Vendor kernels

### Install

- Flash an Armbian CLI image for your board (`jammy`, `noble`, `bookworm`, or `trixie` for now)
  - Alternatively, you can use an Armbian desktop image, but GDM3/SDDM/LightDM will be disabled and Kodi will take over
  - For CLI images, you still need the mesa/panfrost or mail/panfork stack
- Download the .deb from the [releases page](https://github.com/armsurvivors/kodi-rockchip-deb/releases), apprpriate for your Armbian distro (`jammy`, `noble`, `bookworm`, or `trixie`)
- From an SSH or console connection (not in X11 or Wayland), 
  - ✅ install with `apt install ./kodi-rockchip-gbm*.deb`
  - ❌ `dpkg -i` won't work as it doesn't pull dependencies
  - ℹ️ during install, it will disable your display manager if you have one running
- Start the service with `sudo systemctl start kodi`
  - `kodi` service uses ALSA directly, look around for the PulseAudio version if you prefer that

### Troubleshooting

If converting a desktop image, you might need to reboot to cleanup display server usage.