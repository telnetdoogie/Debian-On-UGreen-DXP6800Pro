# Restic Tag-Based Backup Scripts

A lightweight, composable backup system built around **restic** and **tag-driven workflows**.

This repository provides shell scripts for defining, running, and retaining backups using a simple JSON configuration model. It is designed for operators who want predictable, scriptable backups without introducing heavy orchestration tools.

---

## Key Concepts

* **Tag-driven backups**
  Each backup job is grouped under a tag (e.g., `docker`, `system`, `media`).

* **Declarative configuration**
  Backup jobs and retention policies are defined in a single JSON file.

* **Separation of concerns**
  Backup, retention (`forget`), and pruning are executed independently.

* **Pre/Post hooks**
  Optional scripts allow coordination with running systems (e.g., stopping services, creating snapshots).

---

## Features

* Tag-based backup execution
* Per-tag retention policies
* JSON-based configuration
* Pre/post execution hooks
* Safe shell practices (`set -euo pipefail`)
* Compatible with any restic backend (S3, B2, local, etc.)
* Designed for cron/systemd/monit usage

---

## Repository Structure

```
.
├── backup-tags.json     # Backup job definitions
├── backup_common.sh     # Shared validation and helper functions
├── tag_backup.sh        # Run backup for a single tag
├── tag-forget.sh        # Apply retention policy for a tag
├── backup-all.sh        # Run all backups
├── forget-all.sh        # Apply retention across all tags
└── backup-prune.sh      # Run restic prune
```

---

## Requirements

* `restic`
* `jq`
* Bash

---

## Setup

### 1. Configure restic environment

Create an environment file (example: `/etc/restic-env`):

```bash
export RESTIC_REPOSITORY="s3:s3.us-west-002.backblazeb2.com/your-bucket"
export RESTIC_PASSWORD_FILE="/etc/restic-password"
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

Ensure it is readable by the user running the scripts. The `/etc/restic-password` file should contain your restic encryption password. Save it in your password manager too!

---

### 2. Define backup jobs

Edit `backup-tags.json`:

```json
{
  "docker": {
    "job_description": "Docker volumes",
    "backup_path": "/volume1/docker",
    "pre_script": "/path/to/pre-script.sh",
    "post_script": "/path/to/post-script.sh",
    "keep": {
      "daily": 3,
      "weekly": 1,
      "monthly": 6
    }
  }
}
```

#### Fields

| Field             | Required | Description                        |
| ----------------- | -------- | ---------------------------------- |
| `job_description` | No       | Human-readable description         |
| `backup_path`     | Yes      | Path to back up                    |
| `pre_script`      | No       | Script to run before backup        |
| `post_script`     | No       | Script to run after backup         |
| `keep`            | No       | Retention policy (restic `forget`) |

If `keep` is omitted, no retention policy will be applied for that tag.

---

## Usage

### Run backup for a single tag

```bash
./tag_backup.sh <tag>
```

---

### Apply retention policy for a tag

```bash
./tag-forget.sh <tag>
```

---

### Run all backups

(you should modify the `backup-all.sh` script to ensure all your tags are listed, and you've chosen your preferred order. I might add 'priority' to the JSON so this can just run all jobs like the others)

```bash
./backup-all.sh
```

---

### Apply retention for all tags

```bash
./forget-all.sh
```

---

### Prune repository

```bash
./backup-prune.sh
```

---

## Scheduling Example (cron)

```bash
# Nightly backups
0 1 * * * flock -n /var/lock/restic.lock ./backup-all.sh

# Retention cleanup
0 3 * * * flock -w 1200 /var/lock/restic.lock ./forget-all.sh

# Weekly prune
30 3 * * 0 flock -w 1200 /var/lock/restic.lock ./backup-prune.sh
```

Using `flock` is recommended to prevent overlapping runs.

---

## Design Principles

* **Explicit over implicit**
  All backup behavior is defined in configuration, not hidden in scripts.

* **Composable operations**
  Backup, retention, and pruning can be run independently or combined.

* **Operational safety**
  Pre/post hooks allow safe handling of stateful systems.

* **Minimal dependencies**
  Only `restic`, `jq`, and bash are required.

---

## Notes

* Scripts are intended to be run with sufficient permissions to access backup paths.
* Ensure pre/post scripts are idempotent and executable.
* Logging should be handled externally (cron, systemd, or monit).

