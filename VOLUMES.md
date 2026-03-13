# Installing Debian on your UGreen DXP6800 Pro NAS - Volumes, Subvolumes, and Snapshots

## Validating / Checking drives
Install your drives into the NAS, and let's check them for health.
1. `sudo lsblk` will show you the list of drives.
1. You can also use cockpit to see the drives and run healthchecks from there.
1. `sudo smartctl -a /dev/sda` will show you the drive's health.
1. `sudo smartctl -x /dev/sda` will show you the extended SMART attributes.
1. Make sure your drives are healthy before you start setting up RAID arrays. initialization and growing arrays can take a toll on your drives.

---

## Removing the throttles on raid recovery / creation

1. `sudo cat /proc/sys/dev/raid/speed_limit_min` will show you the min speed limit
1. `sudo cat /proc/sys/dev/raid/speed_limit_max` will show you the max speed limit
1. `sudo echo 500000 > /proc/sys/dev/raid/speed_limit_min` will set the min speed limit to 500MB/s
1. `sudo echo 2000000 > /proc/sys/dev/raid/speed_limit_max` will set the max speed limit to 2GB/s
1. To make these changes permanent / updated at boot time, add a file `/etc/sysctl.d/99-raid.conf` with the following contents:
    ```
    dev.raid.speed_limit_min=500000
    dev.raid.speed_limit_max=2000000
    ```

---

## Creating the RAID array

1. It's probably easiest to use cockpit to create the RAID array. 
1. In "Storage", click the hamburger icon in the top right of the drives and choose "Create MDRAID device"
1. Select the drives you want to participate in the array.
1. I chose a chunk size of 64K which is a good middle-ground for files of different sizes.
1. Once you hit "Create", you will wait a LONG time for the array to build.
1. You can watch the progress in the cockpit dashboard, or in a shell:
   * `sudo watch cat /proc/mdstat`
1. Update the stripe cache size to 8192 (you can do this while it's building)
   * you should run `sudo cat /proc/mdstat` to see the device name. The below shows a device name of `md127`.
     ```
     Personalities : [raid0] [raid1] [raid6] [raid5] [raid4] [raid10]
     md127 : active raid5 sdc[3] sdb[1] sda[0]
     15627788928 blocks super 1.2 level 5, 64k chunk, algorithm 2 [3/2] [UU_]
     [=>...................]  recovery =  7.1% (561532492/7813894464) finish=460.9min speed=262201K/sec
      unused devices: <none>  
     ``` 
   * using that device, name, run `sudo echo 8192 > /sys/block/md127/md/stripe_size`
1. Wait... for a LONG time.
1. Once the array is built, let's validate some things.
1. `cat /proc/mdstat` should show the array is active and healthy. 
1. If you don't see 'bitmap' there, we'll need to set that. It will significantly speed up resyncs after an unclean shutdown.
1. Set up the write-intent bitmap:
   * `sudo mdadm --grow /dev/md127 --bitmap=internal` (replace 127 with the device name) 
   * verify with `sudo mdadm --detail /dev/md127` - you should now see an "Intent Bitmap" entry.
   * you should also see a "bitmap" line with `cat /proc/mdstat` for the array now.
1. Let's add the array info to `/etc/mdadm/mdadm.conf`:
   * `sudo mdadm --detail --scan /dev/md127 | sudo tee -a /etc/mdadm/mdadm.conf`
   * you should now have an ARRAY line at the bottom of `sudo cat /etc/mdadm/mdadm.conf`
1. Rebuild initramfs so the RAID assembles during boot: `sudo update-initramfs -u`

---

## Creating the Storage Volume

1. Again, you can format using cockpit which makes things pretty easy.
1. In "Storage, click the ellipsis on the right of the MDRAID device and choose "Format"
1. Name the volume (I chose "volume1")
1. Select the mount point (I used `/volume1`)
1. Set the type to `btrfs`
1. No encryption
1. for the "At boot" option, choose "Mount without waiting, ignore failure"
1. Select "Format and Mount"
1. You should confirm that the volume is mounted, and that you have a /etc/fstab entry that refers to the UUID of the array.
   * `sudo cat /etc/fstab` should look something like:
     ```
     # /etc/fstab: static file system information.
     #
     # Use 'blkid' to print the universally unique identifier for a
     # device; this may be used with UUID= as a more robust way to name devices
     # that works even if disks are added and removed. See fstab(5).
     #
     # systemd generates mount units based on this file, see systemd.mount(5).
     # Please run 'systemctl daemon-reload' after making changes here.
     #
     # <file system> <mount point>   <type>  <options>       <dump>  <pass>
     # / was on /dev/nvme0n1p2 during installation
     UUID=a371bcc7-b01c-4086-ba80-aabbccddeeff /               btrfs   defaults,subvol=@rootfs 0       0
     # /boot/efi was on /dev/nvme0n1p1 during installation
     UUID=E4D7-B6B9  /boot/efi       vfat    umask=0077      0       1
     # swap was on /dev/nvme0n1p3 during installation
     UUID=f9b12cb0-787a-49f9-aa09-aabbccddeeff none            swap    sw              0       0
     UUID=133dd31a-0ad7-4fc6-81a6-aabbccddeeff /volume1 auto nofail,subvol=/,x-parent=42d12f32:bd99095f:63809c36:8eaaaffa 0 0
     ```
   * I like to clean out the excess comments from this file, leave the mounts in place, and format it using `column`
     * `sudo cp /etc/fstab /etc/fstab.orig`
     * `sudo sed -i '/^#/d' /etc/fstab`
     * `sudo column -t /etc/fstab | sudo tee /etc/fstab.new`
     * check the new version: `sudo cat /etc/fstab.new`
     * If it looks good, overwrite the original: `sudo mv /etc/fstab.new /etc/fstab`
   * Time to reboot and make sure everything comes back up properly, and `/volume1` is mounted.
     * `sudo reboot now`
     * When we're back up, we can verify that the raid is good and the volume is mounted: 
       * `cat /proc/mdstat` should show the array is active and healthy (we're looking for `[UUU]`)
       * `findmnt /volume1`
1. You got your first volume created on your new RAID! 
