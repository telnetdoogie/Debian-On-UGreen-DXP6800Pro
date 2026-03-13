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

