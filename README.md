### Warning: vendor/legacy/bsp kernel stuff

`UPDATED: early May 2025 :: Status: WORKS AGAIN`

- for Rockchip rk35xx devices that support rkmpp and rkrga
- Requires either:
    - Armbian rk35xx vendor kernel (6.1-rkr5 or later, with backported Panthor; requires 24.1+ mesa)
    - Armbian rk35xx legacy kernel (5.10-rkr8, 5.10.290, which requires mali blobs/panfork - NOT RECOMMENDED NOR TESTED
      but might work)

### kodi-rockchip-deb

> mainline Kodi for rk35xx hwaccel Rockchip's MPP and RGA via ffmpeg-rockchip, via boogie/nyanmisaka/joshua/amazingfate
> magic; rk bsp/vendor/legacy kernel required.

#### Features

- mainline Kodi
    - In the beggining there was boogie PR https://github.com/xbmc/xbmc/pull/24431 -- we cherry-picked from that and
      life was good.
    - Then that PR got merged -- we got from master, and life was good.
    - Then, the whoile thing got reverted in https://github.com/xbmc/xbmc/pull/25864
    - So now we revert the revert so Rockchip does the boogie again
- ffmpeg-rockchip 7.1 from nyanmisaka
- fully accelerated (`GBM`+`rkmpp`+`rkrga`+`AFBC`),
  see https://github.com/nyanmisaka/ffmpeg-rockchip/wiki/Rendering#kodi-under-gbm
    - > _This type of rendering is the fastest method you can get. To run kodi with gbm support, the active Desktop
      Environment must be stopped so that Kodi can directly interact with KMS_
- works with Armbian rockchip rk35xx vendor kernel

### Install

- Flash an Armbian CLI image for your board (`trixie` is best for now - May 2025)
    - Alternatively, you can use an Armbian desktop image, but GDM3/SDDM/LightDM will be disabled and Kodi will take
      over
    - For CLI images, you still need the pathor overlay (for vendor `6.1-rkrX`) or mali-blob/panfork (for `5.10-rkrX`)
- Make sure you have panthor enabled - check `/boot/armbianEnv.txt` for `overlays=panthor-gpu`
    - Really, this won't work without panthor; make sure init is initialized correctly with
      `dmesg --color=always | grep panthor`
        - Ensure you've the required Mali firmware, it should be present in `apt install armbian-firmware` which is
          installed by default
- Download the .deb from the [releases page](https://github.com/armsurvivors/kodi-rockchip-deb/releases), apprpriate for your Armbian distro (`bookworm`, or `trixie`)
- From an SSH or console connection (not in X11 or Wayland),
    - ✅ install with `apt install ./kodi-rockchip-gbm*.deb` - it will download a ton of dependencies
    - ❌ `dpkg -i` won't work as it doesn't pull dependencies
    - ℹ️ during install, it will disable your display manager if you have one running
- Start the service with `sudo systemctl start kodi`
    - `kodi` service uses ALSA directly, look around for the PulseAudio version (`kodi-pulse`) if you prefer that

### Troubleshooting

- If converting a desktop image, you might need to reboot to cleanup display server usage.
- Tested on rk3588, other rk35xx untested; try and report back (3566/3568 testers needed)

## TO-DO

- [ ] Don't run as root
- [ ] Don't expose Pulseaudio to the network
- [ ] Fix MCE Remote OK/Back buttons (Q: is it 2011 again? A: no, it's just LibreELEC is more awesome.)

## Building

- This is built in a Docker container
- Look at the GHA workflow for the steps
- Definitely requires `docker buildx` / `BuildKit`
- Output is an empty image with a .deb -- use buildx and --output type=local to get the .deb out of there
- Can only be built _on_ arm64 - no cross-compilation
