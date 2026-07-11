### Warning: vendor/legacy/bsp kernel stuff

`UPDATED: early May 2026 :: Status: WORKS!`

- for Rockchip rk35xx devices that support rkmpp and rkrga
    - known to work with `rk3588`, `rk3588s`, `rk3576`, `rk3566`, `rk3568`, `rk3528` and `rk3518` with varying levels of
      hw support and stability
- Requires either:
    - Armbian rk35xx vendor kernel (6.1-rkr5 or later, with backported Panthor; requires 24.1+ mesa)
    - Armbian rk35xx legacy kernel (5.10-rkr8, 5.10.290, which requires mali blobs/panfork - NOT RECOMMENDED NOR TESTED
      but might work)

### kodi-rockchip-deb

> mainline Kodi for rk35xx hwaccel Rockchip's MPP and RGA via ffmpeg-rockchip, via boogie/nyanmisaka/joshua/amazingfate
> magic; rk bsp/vendor/legacy kernel required.

### Caveats

Understand:

- this is meant to be installed on a CLI/server Armbian image, and will disable any display manager (GDM3/SDDM/LightDM)
  to take over the display itself.
- ⚠️ it's not a proper Debian package as it deploys to `/usr/local`
    - The sample systemd units run as root.
- ‼️ Using a vendor kernel like Rockchip's has inherent security implications.
    - For proper, mainline, work see LibreELEC.tv

#### Features

- mainline Kodi
    - In the beggining there was boogie PR https://github.com/xbmc/xbmc/pull/24431 -- we cherry-picked from that and
      life was good.
    - Then that PR got merged -- we got from master, and life was good.
    - Then, the whoile thing got reverted in https://github.com/xbmc/xbmc/pull/25864
    - So now we revert the revert so Rockchip does the boogie again
    - May'2026: boogie/reardonia/chewitt at-it again, see https://github.com/xbmc/xbmc/pull/27402 - using plain `master`
      again
- ffmpeg-rockchip 7.1 from nyanmisaka
- fully accelerated (`GBM`+`rkmpp`+`rkrga`),
  see https://github.com/nyanmisaka/ffmpeg-rockchip/wiki/Rendering#kodi-under-gbm
    - > _This type of rendering is the fastest method you can get. To run kodi with gbm support, the active Desktop
      Environment must be stopped so that Kodi can directly interact with KMS_
- works with Armbian rockchip rk35xx vendor kernel

### Install

- Flash an Armbian CLI image for your board (`trixie` is best for now - May 2025)
    - Alternatively, you can use an Armbian desktop image, but GDM3/SDDM/LightDM will be disabled and Kodi will take
      over
    - For CLI images, you still need the pathor overlay (for vendor `6.1-rkrX`) or mali-blob/panfork (for `5.10-rkrX`)
- (rk3588) Make sure you have panthor enabled - check `/boot/armbianEnv.txt` for `overlays=panthor-gpu`
    - Really, this won't work without panthor; make sure init is initialized correctly with
      `dmesg --color=always | grep panthor`
        - Ensure you've the required Mali firmware, it should be present in `apt install armbian-firmware` which is
          installed by default
    - for other rk35xx, make sure you have the required mali blobs or panfrost going
- Download the .deb from the [releases page](https://github.com/armsurvivors/kodi-rockchip-deb/releases), appropriate
  for your Armbian distro (`bookworm`, or `trixie`)
- From an SSH or console connection (not in X11 or Wayland),
    - ✅ install with `apt install ./kodi-rockchip-gbm*.deb` - it will download a ton of dependencies
    - ❌ `dpkg -i` won't work as it doesn't pull dependencies
    - ℹ️ during install, it will disable your display manager if you have one running
- Start the service with `sudo systemctl start kodi`
    - `kodi` service uses ALSA directly, look around for the PulseAudio version (`kodi-pulse`) if you prefer that
- Configure Kodi in Player > Videos, set DRM Prime and HW accel and render "Direct to Plane"

### Running with Docker/containerd

- Prepare an Armbian CLI image the same way as above, but don't install the .deb
- Instead install Docker or containerd+nerdctl
- Stop any display manager if you have one running
- Run the container with:
  - `nerdctl run -it --privileged --network host --volume /dev:/dev --volume /run:/run ghcr.io/armsurvivors/kodi-rockchip-deb:trixie-latest kodi --logging=console`
    - similar for Docker
- You can add more `--volume` mounts for `/root.kodi` so your config persists

### Troubleshooting

- If converting a desktop image, you might need to reboot to cleanup display server usage.
- Tested on rk3588, other rk35xx untested; try and report back (3566/3568 testers needed)

## TO-DO

- [ ] Don't run as root via systemd
- [ ] Don't expose Pulseaudio to the network
- [x] Fix MCE Remote OK/Back buttons (via LibreELEC patches)

## Building

- This is built in a Docker container
- Look at the GHA workflow for the steps
- Definitely requires `docker buildx` / `BuildKit`
- Output is an empty image with a .deb -- use buildx and --output type=local to get the .deb out of there
- Can only be built _on_ arm64 - no cross-compilation
