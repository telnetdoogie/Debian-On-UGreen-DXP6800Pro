# Installing Debian on your UGreen DXP6800 Pro NAS - Backing up to BackBlaze 

I'll be using `restic` to backup my data to BackBlaze. Previously on my Synology I was using HyperBackup. I've been generally very happy with HyperBackup, however because it's proprietary, it's not 'transferrable' over to a general linux ecosystem.
After doing quite a bit of research I landed on `restic` for its deduplication, speed, integration with BackBlaze, and configurability.
I wanted something to run as a native linux tool as well, versus running a docker container for backups and restores.

## Installing restic
1. This one's pretty simple: `sudo apt install restic`
1. Create a restic environment file, `/etc/restic-env` with the following items:
   ```
   export AWS_ACCESS_KEY_ID=<B2_KEY_ID>
   export AWS_SECRET_ACCESS_KEY=<B2_ApplicationKey>
   export RESTIC_REPOSITORY="s3:<B2_BucketEndpoint>/<BucketName>"
   export RESTIC_PASSWORD_FILE=/etc/restic-password
   ```
1. Create the `etc/restic-password` file and put a generated password in there for your restic backups. Keep this safe elsewhere (password managers are ideal).
1. Secure both of these files so that the root user is the only user than can access them.
    * `sudo chmod 600 /etc/restic-*`
1. Because only root can access these files, when you use restic to do manual backups or change configurations etc., you'll need to `sudo -i` to log in as root and pick up these environment variables.
1. We need to have these picked up when root logs in...
    * Edit `/root/.bashrc` (with `sudo`) and add the following line:
       * `. /etc/restic-env`
1. `sudo -i` to login as root, and check that `restic-env` was loaded: `printenv | grep AWS`
1.  Initialize your restic repository: `restic init` (you don't have to pass `-r` and remember crazy bucket URLs / Endpoints once it's in environment variables)
1.  I will be backing up different folders on different schedules and may have different retention for each folder. The way I'll do that with restic is with `tags`
1.  Let's make our first backup, of the root filesystem. I'm going to tag this set of folders as `rootfs`:
    * `restic backup / --one-file-system --tag rootfs`
      * This will backup `/` including all subfolders
      * `--one-file-system` ensures that it doesn't backup local snapshots (`/.snapshots/`) since they are a subvolume. In my case it also excludes the `/home` folder, because I set that up as a subvolume on the raid device.
    * Let's do another. `restic backup / --one-file-system --tag rootfs` - It will only backup what's changed.
1.  Now let's backup the home folder as well. We'll use the tag `home` for this one.
    * `restic backup /home --one-file-system --tag home`
1.  To show the backups (restic calls these `snapshots` - not to be confused with btrfs snapshots), run `restic snapshots`:
     ```
     restic snapshots
     repository c8ef5942 opened (version 2, compression level auto)
     ID        Time                 Host        Tags        Paths  Size
     ------------------------------------------------------------------------
     48441da7  2026-03-14 23:59:39  DXP6800Pro  rootfs      /      2.797 GiB
     3eae98d5  2026-03-15 00:02:17  DXP6800Pro  rootfs      /      2.798 GiB
     20814866  2026-03-15 00:14:06  DXP6800Pro  home        /home  91.693 KiB
     ------------------------------------------------------------------------
     ```
     * Notice how the size of the two `rootfs` snapshots is roughly the same. However, these ARE similar to btrfs snapshots, in that only the changed blocks are stored in subsequent backups. The size of the data transferred is actually very small.
     * We now have two snapshots of the root filesystem, and one of the home folder.
     * Tags will be incredibly useful for organizing backups.
1.  What if I only want one 'version' of each folder? We can use `restic forget` to remove older snapshots. Here's an example of how we'd manage retention for these backups. I won't go into full detail here, there's lots of articles and videos about how to do all this.
     * Let's try to forget a backup that doesn't exist:
       * `restic forget --tag docker --keep-last 1 --dry-run` (dry-run will just show us what would be deleted)
          ```
          repository c8ef5942 opened (version 2, compression level auto)
          Applying Policy: keep 1 latest snapshots
          ```
          ..nothing.
     * OK Let's remove all but the latest backup of `rootfs`:
       * `restic forget --tag rootfs --keep-last 1 --dry-run`
          ```
          repository c8ef5942 opened (version 2, compression level auto)
                  
          Applying Policy: keep 1 latest snapshots
          keep 1 snapshots:
          ID        Time                 Host        Tags        Reasons        Paths  Size
          --------------------------------------------------------------------------------------
          3eae98d5  2026-03-15 00:02:17  DXP6800Pro  rootfs      last snapshot  /      2.798 GiB
          --------------------------------------------------------------------------------------
          1 snapshots
          
          remove 1 snapshots:
          ID        Time                 Host        Tags        Paths  Size
          -----------------------------------------------------------------------
          48441da7  2026-03-14 23:59:39  DXP6800Pro  rootfs      /      2.797 GiB
          -----------------------------------------------------------------------
          1 snapshots
          
          Would have removed the following snapshots:
          {48441da7}
          ```
          ... it will remove the earliest snapshot and keep the latest.
1.  Forgetting a backup removes the backup from the list, however it doesn't delete the data. That must be done by `prune`ing. You will need schedules to:
    * `backup` data periodically (with tags if that's helpful)
    * `forget` backup versions (snapshots) - and restic has some pretty versatile retention policies, just like HyperBackup does:
       * `--keep-daily n`
       * `--keep-weekly n`
       * `--keep-monthly n`
       * `--keep-yearly n`
       * `--keep-last n` 
          ...These all allow you to setup some really nice retention.
    * `prune` old snapshots (actually remove the unused data from the repository)
    * Again... all of these can be done "by tag"
    * See [removal policy](https://restic.readthedocs.io/en/stable/060_forget.html#removing-snapshots-according-to-a-policy)
1.  One amazing thing about restic is that deduplication works across all tags... so if you have the same file on three different backups / tags / subvolumes, it will only store those bytes once.
2.  If backing up to a remote repository (like BackBlaze) – you may reduce the number of requests that are made to backblaze and therefore transaction costs by increasing the `RESTIC_PACK_SIZE` to 32–64MB. This has to be done before creating your repository. If you want to change that value, you can add it to your `/etc/restic-env` file. See [tuning](https://restic.readthedocs.io/en/stable/047_tuning_backup_parameters.html#pack-size)
    * `export RESTIC_PACK_SIZE=64`
  
---

# Automation 

- See my scripts and how I've automated restic backups based on restic **tags** [here](./scripts/backup/)
