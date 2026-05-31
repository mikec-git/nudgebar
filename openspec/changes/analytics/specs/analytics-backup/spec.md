## ADDED Requirements

### Requirement: Nightly database backup

The system SHALL produce a nightly `pg_dump` of the Umami database to a server-side location under `/srv`, on a schedule (systemd timer or cron).

#### Scenario: Scheduled dump runs

- **WHEN** the nightly backup schedule fires
- **THEN** a timestamped `pg_dump` of the Umami database is written to the backup directory

#### Scenario: Manual dump on demand

- **WHEN** the backup command is run manually
- **THEN** a current dump is produced without interrupting the running Umami service

### Requirement: Backup retention

Backups SHALL be retained for a bounded window so old dumps do not accumulate without limit.

#### Scenario: Old dumps are pruned

- **WHEN** the backup runs and dumps older than the retention window exist
- **THEN** dumps older than the retention window are removed and recent dumps are kept

### Requirement: Documented restore path

There SHALL be a documented procedure to restore the Umami database from a dump.

#### Scenario: Restore from a dump

- **WHEN** an operator follows the documented restore procedure against a chosen dump
- **THEN** the Umami database is restored to the state captured in that dump
