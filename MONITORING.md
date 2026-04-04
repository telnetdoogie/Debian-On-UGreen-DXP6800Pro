# My collection of custom monitors for `monit`

Here I'll capture some of the more advanced monitoring I've added over time, usually with custom scripts.

For some monitors you may need to install `lm-sensors`, and/or make sure you have the correct kernel modules installed.

These are all `monit` scripts that I've added to my NAS. I have placed all of the custom scripts in [/scripts/monitoring/](./scripts/monitoring) in this repo.

---

**Check CPU Temperature**
   * `.monitor` entry:
     ```
     ## Check CPU temperature, pass the max temp
     check program cpu_temp with path "/usr/local/bin/check_cpu_temp 80"
         if status == 1 for 2 cycles then alert
         if status == 2 then alert
     ```
   * `check_cpu_temp` file [here](./scripts/monitoring/check_cpu_temp)


**Check for increasing CPU throttling events (indicator of overheating)**
* `.monitor` entry:
  ```
  ## Check thermal throttle counts
  check program thermal_throttle with path "/usr/local/bin/check_throttle.sh"
      if status != 0 then alert
  ```
* `check_throttle.sh` file [here](./scripts/monitoring/check_throttle.sh)

**Check that backups have been run recently**
* `.monitor` entry:
  ```
  ## Check for recent successful backups
  check program backup-health with path /usr/local/bin/check_recent_backups.sh every 180 cycles
      if status !=0 then alert
  ```
* `check_recent_backups.sh` file [here](./scripts/monitoring/check_recent_backups.sh)

**Check for unhealthy or stopped docker containers**
* `.monitor` entry:
  ```
  ## Check for unhealthy docker containers (5 cycles =~ 10 min)
  check program docker-health with path /usr/local/bin/docker_health.sh every 5 cycles
      if status !=0 for 2 cycles then alert
  ```
* `docker_health.sh` file [here](./scripts/monitoring/docker_health.sh)


     