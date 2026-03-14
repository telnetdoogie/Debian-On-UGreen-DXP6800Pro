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

---

# Adding subvolumes...

There are a few things I want to do which are will help with storage space, snapshots, backups, and fine tuning storage folders for things like compression at the 'top level folder' level. These are mostly inspired by my experience with Synology NAS, which I think did a pretty good job of making the most of btrfs filesystems.
* Move `/home` (and existing contents) to `/volume1/@homes` - and enable compression.
* Move `/var/lib/docker` to `/volume1/@docker-engine` - and enable compression. This will ensure the docker images don't fill the root filesystem
* Create subvolumes for our important folders, (most of which will be compressed)
  * `/volume1/Backups` - for backups
  * `/volume1/Docker` - for our Docker folder
  * `/volume1/Businessy Things` - for our special stuff
  * `/volume1/Media` (which won't be compressed)
* Create a subvolume for snapshots
  * `/volume1/@snapshots` - this will allow us to have a central place for btrfs snapshots.

I intend to use snapshots for simplifying backups using `restic`, so for example, for docker backups, I might run a script nightly to:
  1. Backup in-container databases using their native backup methods to `nightly.sql` or similar
  1. Take a snapshot ot the `/docker` subvolume
  1. Backup the snapshot to Backblaze, keeping x daily, weekly, monthly versions etc.
This would make backups fast and simple, without needing to have downtime. Alternatively I could stop the docker service, take the snapshot, and then restart docker once the snapshot is taken. The downside of this is that given the number of containers I typically run, this downtime might be unacceptably long and cause quite a bit of CPU load at service start. So I intend to play around with these options a little.

## Moving `/home` --> `/volume1/@homes`
1. Let's start by moving the `/home` folder to a new subvolume. This will give us tons of room for users in their home folders on the RAID storage.
1. First of all, we'll need `rsync` installed for this. `sudo apt install rsync`
1. Creating subvolumes is pretty simple. Let's make one for this.
   * `sudo btrfs subvolume create /volume1/@homes`
1. Now you have a subvolume in `/volume1` called `@homes`. `sudo btrfs subvolume list /volume1` should show you the subvolume.
1. Because we want to apply different options to these subvolumes (compression, etc), we will want to explicitly mount these subvolumes in `/etc/fstab`.
1. BUT in this case, because we already have data in `/home` (and `/home` is currently on our root filesystem (the OS drive), we'll need to do some dancing.
1. If you can still use HDMI and mouse / keyboard, you can skip the following few steps since you won't have trouble logging in as the `root` user, who has their own special home directory.
   * First, we'll need to [temporarily] allow root to `ssh` into the machine.
   * edit `/etc/ssh/ssd_config` and change the `PermitRootLogin` line to `PermitRootLogin yes`
   * `sudo systemctl restart sshd`
   * You should now be able to ssh into the machine as the `root` user using the password you set up at install time.
1. login to the machine as the `root` user.
1. Because we want to compress the `/home` folder, and compression will only work on new files, not existing files, we'll make sure we can set up compression before moving things around, so existing files will get the benefit of compression.
1. Create a temporary mount point: `sudo mkdir /mnt/newhome`
1. Grab the UUID of the RAID array: `lsblk -f` - use the UUID from `/volume1` - (`mdx` not the drive `sdx`)
1. Because we mounted `/volume1` without compression, we'll need to re-mount it with compression.
1. Edit `/etc/fstab` and edit the options for `/volume1` to include `compress=zstd`
   * `UUID=133dd31a...ff  /volume1   auto   compress=zstd,nofail,subvol=/...`
1. `systemctl daemon-reload`
1. `umount -a`
1. `mount -a`
1. You should now see compression on the `/volume1` mount point. `findmnt /volume1` should show compression.
1. Now we can mount the subvolume: `mount -o subvol=@homes,compress=zstd UUID=<uuid here> /mnt/newhome`
1. compression should be enabled: `findmnt /mnt/newhome`
1. Copy the current `/home` folder into the new subvolume: `rsync -aAXHv --numeric-ids /home/ /mnt/newhome/`
1. Move the old `/home` folder: `mv /home /home.old`
1. Create a mount point: `mkdir /home`
1. Update /etc/fstab to mount the subvolume to the new mount point
   * Copy the line you already have for `/volume1`
   * On the new line, change the mount point to `/home`
   * On the new line, change the subvolume from `/` to `@homes`, and remove x-parent option.
   * Instead of:
     ```
     UUID=133dd31a-0ad7-4fc6-81a6-447b394d797b  /volume1   btrfs   compress=zstd,nofail,subvol=/,x-parent=42d12f32:bd99095f:63809c36:8eaaaffa  0  0
     ```
   * You should now have:
     ```
     UUID=133dd31a-0ad7-4fc6-81a6-447b394d797b  /volume1   btrfs   compress=zstd,nofail,subvol=/,x-parent=42d12f32:bd99095f:63809c36:8eaaaffa  0  0
     UUID=133dd31a-0ad7-4fc6-81a6-447b394d797b  /home      btrfs   compress=zstd,nofail,subvol=@homes  0  0
     ```
   * `umount /home`
   * `mount /home`
1. Verify that your `/home` folder looks correct.
1. Verify that it's actually mounted from the subvolume: `findmnt /home`
1. Now if you're good with the move, you can remove `/home.old` and `/mnt/newhome` : `rm -Rf /home.old /mnt/newhome`
1. If you modified `etc/ssh/sshd_config` to allow root to ssh, you can revert that change.
1. If you want to validate that files are compressed, install `btrfs-compsize` using `apt` and run it on the `/home` folder (`sudo compsize /home`)

## Setting up `/var/lib/docker` --> `/volume1/@docker-engine`
1. `sudo btrfs subvolume create /volume1/@docker-engine`
2. Add it to `/etc/fstab`
   * copy that same entry from before when you did /home... Change the subvol and the mount point
   * The subvolume is `@docker-engine`, and the mount point is `/var/lib/docker`
1. Make the mount point: `sudo mkdir /var/lib/docker`
1. `sudo systemctl daemon-reload`
1. `sudo mount -a`
1. Validate using `findmnt /var/lib/docker`
1. This one's ready to go. When you install docker it'll use that folder for docker's internals.

## Setting up `/volume1/docker` 
1. This one's much easier... we don't need a special mount for this one, but in the interest of uniformity I'll do it anyway.
1. `sudo btrfs subvolume create /volume1/docker`
1. Add it to `/etc/fstab`
    * copy that same entry from before when you did /home. subvol is `docker` and mount point is `/volume1/docker`
1. `sudo systemctl daemon-reload`
1. Mount it. `sudo mount -a`
1. This one's done.

## Setting up `/volume1/Media`
1. Another easy one, but for this one we'll disable compression (no need if we plan on having lots of huge mkv files)
1. `sudo btrfs subvolume create /volume1/Media`
1. Add it to `/etc/fstab`
   * copy that same entry from before when you did /home. subvol is `Media` and mount point is `/volume1/Media`
   * you can add the option `compress=no` - however that won't work. I'm just using that to leave a note for intention.
1. To remove compression from this subvolume, we must modify the btrfs properties: `sudo btrfs property set /volume1/Media compression none
1. Mount it. `sudo mount -a`
1. Done.

## Install docker
1. Since we've created the @docker-engine subvolume, let's go ahead and install docker now.
1. Install by following all the steps from the official [docs](https://docs.docker.com/engine/install/debian/)
1. Validate docker is installed: `docker info`
1. docker sets up a `docker` group, so add your admin user (or whichever user you'll use to install containers) to the docker group:
   * `sudo usermod -aG docker $USER`
   * log out, and back in again to pick up the new group membership.
1. Double-check that the `/var/lib/docker` folder is mounted to the subvolume: `findmnt /var/lib/docker`
1. Run a quick hello-world with docker to ensure it's setup correctly. You shouldn't have to use sudo to do this. If you can't do it without `sudo` you may need to check you're correctly in the `docker` group.
   * `docker run --rm hello-world`
1. Docker is ready to go!

# Let's get some filesharing going!
1. We don't have much stored yet, but let's give users on Windows visibility into their home folders.
2. `sudo apt install samba wsdd2`
3. Modify the `/etc/samba/smb.conf` file:
   ```
   [global]
   server string = {FQDN for machine name here}
   netbios name = {machine name here{}
   workgroup = {change this to your workgroup}
   security = user
   # comment the below line out
   ;   map to guest = bad user  

   [homes]
   comment = Home Directories
   browseable = no
   writable = yes
   valid users = %S
   create mask = 0664
   directory mask = 0775
   
   [Media]
   comment = Media Share
   path = /volume1/Media
   browseable = yes
   writable = yes
   valid users = %S, @users
   create mask = 0664
   directory mask = 0775
   ```
1. Create a Samba password for your user(s):
   * `sudo smbpasswd -a <username>`
1. Restart Samba: `sudo systemctl restart smbd nmbd`
1. Start the ws-discovery service so windows client can see the server: `sudo systemctl enable wsdd2.service`
1. Add your user(s) to the `users` group (using cockpit for this is simple)
1. For the "Media" share in this example:
   * Change the owner of the `/volume1/Media` folder to be owned by someone in the `users` group:
     * `sudo chown admin:users /volume1/Media`
   * Make sure that `users` can read / write to this folder:
     * `sudo chmod 774 /volume1/Media`
1. You should now be able to see the machine in Windows Explorer, and you should be able to access your home folder as well as the `Media` share.

---

## Migrating data from another NAS (Synology, in my case)

1. After creating destination folders / volumes on the UGreen, there are a few ways to start moving data from the old location to the new.
1. In my case, I need to keep some apps on the old NAS running, so I can't pull drives and mount partitions etc. I don't know if that would work, but it's not something I was able to do since I needed to keep things up and running on the old NAS.
1. I settled on using rsync over SSH to sync the contents of folders over to the new NAS. It's not the fastest (especially if your old NAS has slow drives and a single 1Gb ethernet link) - but it works.
1. Here's the command I used to move files. You can run it multiple times if the data on the source changes. It will only update changed files (deleted, added, or modified) - you run this on the destination (the new NAS)
     ```
     sudo rsync -avP --delete \
             --exclude=".snapshots"  \
             --exclude="@eaDir"     \
             --exclude="#recycle"   \
             --exclude="Thumbs.db"  \
             --exclude=".DS_Store"  \
     username@oldNAS:/volume1/SourceFolder/ /volume1/DestinationFolder/
     ```
     * don't forget the slashes at the ends of the folders. 
1. Some explanations:
   * `--delete` deletes files from the destination that have been removed from the source. Very handy if data is changing on the source
   * `--exclude=".snapshots"` is very important if you want to preserve your snapshots on the destination and they're in the default location that snapper creates (`.snapshots` on the subvolume) - otherwise rsync will try to delete snapshots on the destination as it sees them as regular files.
   *  The other `excludes` just exclude annoying files that were on the source that I don't want to move over, mostly synology-generated files that aren't important after the move.
1. Again - you can run this same command multiple times over multiple days and since migration could take a few days, that's probably a good idea unless you've already totally stopped using the source device. For me, migration of data has taken days, and so I want to make sure I continue to run these until the last moment so I know I've left nothing behind.
1. If you are moving files from a live filesystem where apps are still running - docker apps and dbs being one example - you will want to find a 'cutoff point' when you shut those apps down and migrate the data. Once that's done it'd be a great idea to take a snapshot on the destination, if you want to still run the apps on the source... that way at worst you've got a good 'backup' of the filesystem taken from when the apps / containers were shut down, in case you run into state issues or problems with DBs when you deploy those same apps on the new NAS.
1. Running this command with `sudo` should allow you to preserve permissions exactly as they were on the source filesystem (even if those users aren't on the destination)
1. In the case of synology, rsync should be able to read all files, because /bin/rsync has the setuid bit set which allows rsync to run with root privileges there.
