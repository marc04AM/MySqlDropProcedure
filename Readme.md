## MySql periodiacally drop schema procedure

### Purpose: 
Create a configurable retention mechanism that drops per-day report tables named reports_YYYYMMDD older than a configurable number of days.

### Contents:
  - Enables MySQL event_scheduler
  - Creates config_pruning table to store retention_days (default 30)
  - Stored procedure sp_prune_reports(retention_days) that drops matching old tables
  - Daily event ev_daily_prune_reports invoking the procedure (starts at 09:00 server time)

### Notes:
  - Requires appropriate privileges (EVENT, DROP, and ALTER GLOBAL for enabling scheduler).
  - Adjust retention by updating config_pruning.retention_days (e.g. UPDATE config_pruning SET retention_days = 14 WHERE id = 1).
  - A commented SELECT block is included for dry-run/testing to list tables that would be dropped.
  - Designed for MySQL; table names must follow reports_YYYYMMDD format.
