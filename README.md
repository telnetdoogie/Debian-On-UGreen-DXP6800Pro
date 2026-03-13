# Installing Debian on your UGreen DXP6800 Pro NAS
My Learnings about replacing UGOS with headless Debian on my DXP6800 Pro...
I am using cockpit as a UI to manage the core system, and will use docker containers almost exclusively for applications.

<p style="text-align: center;">
<img width="1042" height="668" alt="image" src="https://github.com/user-attachments/assets/c3901acf-7306-44d0-bca8-2cc033fcccb7" />
</p>


**Note:**
*I am using Debian 13.3.0 (Trixie) netinst 64bit*

I hope this helps you get up and running! 

---

## Before you Start
### _To do any of this without the BIOS rebooting the device due to the watchdog service thinking the device is dead / frozen, you'll need to disable the BIOS watchdog._

...We'll re-enable the watchdog toward the end.
1. Boot NAS to BIOS (UEFI)
    * Use HDMI and monitor with keyboard and mouse
    * *(CTRL-F12 during power-on)*
    * Select the Setup mode
    * Disable the BIOS watching (in advanced)
    * F10 saves and exits.

---

## Backing up the original OS

1. Boot NAS to USB (Macrium Rescue Media)  
   * Use HDMI and monitor with keyboard and mouse 
   * *(CTRL-F12 during power-on)*
   * Select your rescue media to boot to on the boot menu

1. Backup the OS device (device image) to USB

1. Move Backup somewhere safe that itself is backed up 
   * (I used my existing NAS which gets backed up to BackBlaze nightly)

1. Verify moved Backup Image with Macrium (Windows)

---

## Installing Debian (Headless)

1. Connect NAS to Network, ensure working cable, DHCP etc.
   * you can validate network connectivity etc with UGOS or during the Debian install

1. Create Debian `netinst` bootable USB using Rufus or similar tool (on Windows / Mac, your working OS of choice)

1. Boot NAS to USB (Debian Installer)
   * Use HDMI and monitor with keyboard and mouse 
   * *(CTRL-F12 during power-on)*
   * Select your installation media to boot to on the boot menu

1. Select "Graphical Advanced Install..." to install Debian - with modificxations:
   1. Modify the install option "Graphical Advanced Install..." with 'e' to edit grub settings.
      1. add `nomodeset` to GRUB_CMDLINE_LINUX_DEFAULT - this will allow the HDMI to stay alive during install.
1. Use default Partition Layout with modifications (btrfs for root partition):
   ```
   Partition Table: gpt
   Disk Flags:
    
   Number  Start   End     Size    File system     Name  Flags
   1       1049kB  1024MB  1023MB  fat32            boot, legacy_boot, esp
   2       1024MB  121GB   120GB   btrfs
   3       121GB   128GB   6609MB  linux-swap(v1)   swap
   ```
   * Don't be afraid to wipe the existing partitions; that's what the backup was for.

1. Network Interface selection - choose the active network interface to continue the setup. 
   * I used the LAN1 interface
   * The **higher numbered network interface** of the two was `LAN1`.

--- 

## Give yourself `sudo` access

1. Once the install is complete and you've rebooted, login as the user you created. 
1. Give yourself `sudo` access:
   * `su root` (use the root password you set during the install)
   * `sudo usermod -a -G sudo <username you created>`
1. Log out and back in, or reboot.
   * `sudo reboot now`
1. Login as the user you created, and test sudo access.
   * `sudo whoami` should return `root`

---

## Installing Cockpit

1. When logged in, let's install Cockpit:
   * `sudo apt update`
   * `sudo apt install cockpit`
   * `sudo systemctl enable cockpit`
   * `sudo systemctl start cockpit`

1. Test access once installed by visiting `http://<ip>:9090` from your browser.
   * _note: currently, there's a bug in cockpit in the "services" screen that causes refreshes in the browser. 
     * Hit refresh in the browser to stop the constant reloads. It's annoying but benign.
1. Login to Cockput with your user credentials.
1. You'll see a link at the top to get administrative access. Use that. 
1. In the "Networking" screen, you'll see that your active network interface shows as 'unmanaged'. Let's fix that.
1. Install mdadm to manage RAID:
   * `sudo apt install mdadm`
     * (you'll need this to create your RAID volumes later) 
---

## Manage Interfaces in Cockpit, (and rename them to something useful)

1. Move the interface to be managed by NetworkManager: 
   * Edit: `/etc/network/interfaces`
   * Comment out the interface configuration by adding a `#` in front of it:
       ```
       # iface enp87s0 inet dhcp
       ```
    * Edit `/etc/NetworkManager/NetworkManager.conf`:
      ```
       managed=true
      ```
    * Restart NetworkManager with `sudo systemctl restart NetworkManager`
    * Back in cockpit, interfaces should now appear as **managed**.
      * If you had both interfaces live on setup, you'll need to do the above with both interfaces. 
1. Rename interfaces to something useful:
    * Create two files:
      ```
      /etc/systemd/network/10-lan0.link
      /etc/systemd/network/10-lan1.link
      ```
    * Each file will map a network interface to a name, so use the following format:
      ```
      [Match]
      MACAddress=aa:bb:cc:dd:ee:12
      
      [Link]
      Name=lan0
      ```
      * Replace `aa:bb:cc:dd:ee:12` with the MAC address of the interface you want to rename. (you can see them in cockpit or use `ip a` to show them)
    * Reboot the NAS.
    * Once it's rebooted, you should see the interfaces renamed in cockpit.
    
---

## Fix Missing Modules / Resolve Errors

1. Check the cockpit logs and install missing modules if required.
   * you may have to search online for some of the errors - some are fairly benign, but I like to start out as clean as possible.
   * I removed many of the storage errors by installing the below packages:
      ```
      lvm2
      udisks2
      udisks2-lvm
      udisks2-btrfs
      ```
   * I removed the `iscsi` errors by removing the `iscsi` module from the `udisks2` config file:
      * Edit `/etc/udisks2/udisks2.conf`
           ```
           [udisks2]
           modules_disable=iscsi
           ```
    * (Any `intel-hda-sound` error(s) will be taken care of further below when we install firmware)
---

## Install Python for Cockpit Metrics / Graphs

1. In "Overview" screen in Cockpit, click "View Metrics and history"
1. You'll be prompted to install **PCP support** for metrics.
1. This enables the ability to view graphs and metrics in Cockpit.

---

## Create Admin User
I came from Synology and I wanted to emulate the admin user that I use to run all my docker containers, so I am trying to emulate that here as much as possible.
You can skip this part if you don't want the admin user.

1. Add the user: `sudo useradd -m -u 1024 -d /home/admin -g users -s /bin/bash admin`
   * if you're used to 1026 or want to specify a different UID, use that instead of `1024`
   * if you don't care about the UID, omit the `-u 1024` option altogether.
1. Add groups to the user: `sudo usermod -a -G sudo,video,render admin`
   * (adding video and render groups allows the user to use hardware transcoding in your jellyfin / plex etc later)

---

## Add Firmware Packages

You'll want to install these packages to get the Intel drivers for QSV, any firewire drivers etc.

1. `sudo apt install firmware-linux firmware-intel-sound`

---

## Fix GRUB to allows graphic boot

Because we used `nomodeset` in the grub settings, we need to undo that in order to get hardware transcoding working later.

1. Edit `/etc/default/grub`
1. Set:
    ```
    GRUB_CMDLINE_LINUX_DEFAULT="quiet video=DP-1:1024x768@60e"
    GRUB_GFXMODE=1024x768
    ```
1. Update grub with `sudo update-grub`
1. Reboot and verify HDMI output works all the way through bootup and into console.

---

## Intel QSV Validation

Now that we've removed `nomodeset` from the grub settings, you should have access to hardware transcoding devices.

1. Verify that you have the `/dev/dri/renderD128` and `/dev/dri/card0` devices:
   * `ls /dev/dri`
      * Expected result should show `by-path`, `card0`, `renderD128` entries
1. Install `vainfo` to validate the drivers:
    * `sudo apt install vainfo`
    * running `sudo vainfo` should show the below (as well as some benign warnings) 
       ```
       vainfo: VA-API version: 1.22 (libva 2.22.0)
       vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 25.2.3 () 
       ```

---

## Re-Enabling BIOS Watchdog Functionality

Turns out the DXP6800 uses a different device for watchdog than the one that is detected and loaded by default.
This is a problem because the default watchdog device is `/dev/watchdog0` which is not the same one the BIOS uses.

1. Load the kernel module
   * `sudo modprobe it87_wdt`
1. Ensure that you now have an additional watchdog device:
   * `ls -l /dev/watchdog*` should show `/dev/watchdog1`
   * **If you don't see this, don't continue. Your system may differ from mine. If you want to enable the hardware watchdog, you may need to do some testing on your own or see if the default watchdog module is working for you.**
1. Have the module load automatically on boot 
   * Create `/etc/modules-load.d/watchdog.conf`
   * Edit the file so it contains: `it87_wdt`
1. Configure the `systemd` watchdog:
   * Edit `/etc/systemd/system.conf`. Find and change the below values:
     ```
     RuntimeWatchdogSec=30
     RebootWatchdogSec=120
     WatchdogDevice=/dev/watchdog1
     ```
1. Remove legacy watchdog service if it is installed:
    * `sudo apt purge watchdog`
1. Reboot.
1. Verify systemd watchdog:
    * `sudo lsof /dev/watchdog*` should show:
      ```
      systemd ... ... /dev/watchdog1
      ```
    * `sudo wdctl /dev/watchdog*` should show:
      ```
        Device:        /dev/watchdog1
        Identity:      IT87 WDT [version 1]
        Timeout:       30 seconds
        Pre-timeout:    0 seconds
        Pre-timeout governor:
        FLAG           DESCRIPTION               STATUS BOOT-STATUS
        KEEPALIVEPING  Keep alive ping reply          1           0
        MAGICCLOSE     Supports magic close char      0           0
        SETTIMEOUT     Set timeout (in seconds)       0           0
      ```
    * `sudo dmesg | grep -i watchdog` should show `/dev/watchdog1` being used:
       ```
       [...] NMI watchdog: Enabled. Permanently consumes one hw-PMU counter.
       [...] systemd[1]: Using hardware watchdog 'IT87 WDT', version 1, device /dev/watchdog1
       [...] systemd[1]: Watchdog running with a hardware timeout of 30s.
       ```
1. If all is good, reboot to BIOS menu and re-enable the BIOS watchdog.
1. Watch the system for a while, it should no longer reboot after the set time.
1. To negatively test:
    * Change `WatchdogDevice` in `/etc/systemd/system.conf` to `/dev/watchdog0`
    * `sudo systemctl daemon-reload`
    * Reboot
    * Watch the system for a while; System should reboot when `watchdog1` is not fed.
    * You'll have to either undo the above (change `WatchdogDevice` back to `/dev/watchdog1`) and reload things quickly, or disable watchdog in the BIOS to give yourself time to change those settings back before re-enabling.

---

## Mail Sending

1. We're going to setup the simple `msmtp` for sending mail, `msmtp-mta` to provide `sendmail` and `mailutils` for using `mail` in scripts etc.
1. `sudo apt install msmtp msmtp-mta mailutils`
1. Create a config file for msmtp in `/etc/msmtprc`: 
   ```
   defaults
   auth           on
   tls            on
   tls_trust_file /etc/ssl/certs/ca-certificates.crt
   logfile        /var/log/msmtp.log
   
   account gmail
   host smtp.gmail.com
   port 587
   from your_email@gmail.com
   user your_email@gmail.com
   password your_app_password
   
   account default : gmail
   ```
   * (you will need to create an app password for your gmail account and use it here.)
1. Set permissions on the config file: `sudo chmod 600 /etc/msmtprc`
1. Set ownership of the config file: `sudo chown msmptd:msmptd /etc/msmtprc`
1. Set the suid bit on the msmtp executable: `sudo chmod u+s /usr/bin/msmtp`
   * this allows non-root users to send mail with `msmtp` while not exposing your app password in the config to users other than root.
1. Test sending mail: `mail -s "test alert" me@mymail.com` (use your email, obviously)
1. Start the msmtp service: `sudo systemctl enable --now msmtpd.service`

---

## Some simple alerts
Let's try to get some fundamental alerts setup similar to the ones you might be used to from a NAS on a 'traditional' NAS OS.

1. Disk Monitoring:
   * Make sure `smartmontools` is installed. `sudo apt install smartmontools`
   * Edit `/etc/smartd.conf`
   * Edit the DEVICESCAN line: `DEVICESCAN -a -o on -S on -s (S/../.././02) -m me@mymail.com`
      * obviously use your email address here.
      * (the `S/../.././02` is the default scan interval, every morning at 2am
   * Enable the service: `sudo systemctl enable smartmontools`
1. RAID monitoring:
   * edit `/etc/mdadm/mdadm.conf`
      * `MAILADDR` should be your email address.
   * Start the service: `sudo systemctl start mdmonitor`
   * Test the raid alerts: `sudo mdadm --monitor --scan --test`
1. Filesystem usage alerts:
   * Install `monit`: `sudo apt install monit`
   * Edit `/etc/monit/monitrc`:
     ```
     set mailserver localhost
     set alert me@mymail.com
     
     check filesystem rootfs with path /
     if space usage > 90% then alert
     
     check system localhost
     if loadavg (5min) > 10 then alert
     if memory usage > 90% then alert
     if cpu usage > 95% for 5 cycles then alert
     ```
     * (using `10` for loadavg given a 12 core system)
   * Validate the config with `sudo monit -t`
   * Start the service:
     * `sudo systemctl enable --now monit`
   * Show the monitors: `sudo monit -v`


---

## Base Image Snapshot

We've come a long way, and by now things should be fairly stable. We haven't set up RAID or any storage yet. That comes later.
For now, let's take a snapshot so if anything crazy happens later, we can restore from a snapshot.

1. Create snapshots directory
   * `sudo btrfs subvolume create /@snapshots`
1. Create "clean install" snapshot:
   * `sudo btrfs subvolume snapshot -r / /@snapshots/<date>_clean_install`
      *  (change `<date>` to your actual date)
1. You should see your snapshot now in Cockpit / Storage.


---

That's it so far!!! More to come on setting up your volumes and making sensible use of snapshots to tweak each share!

I just starting building my array, but I'll keep documenting as I go. [Volume Setup](./VOLUMES.md)