
-- Purpose: Create a configurable retention mechanism that drops per-day report tables named
--          reports_YYYYMMDD older than a configurable number of days.
-- Contents:
--   - Enables MySQL event_scheduler
--   - Creates config_pruning table to store retention_days (default 30)
--   - Stored procedure sp_prune_reports(retention_days) that drops matching old tables
--   - Daily event ev_daily_prune_reports invoking the procedure (starts at 09:00 server time)
-- Notes:
--   - Requires appropriate privileges (EVENT, DROP, and ALTER GLOBAL for enabling scheduler).
--   - Adjust retention by updating config_pruning.retention_days (e.g. UPDATE config_pruning SET retention_days = 14 WHERE id = 1).
--   - A commented SELECT block is included for dry-run/testing to list tables that would be dropped.
--   - Designed for MySQL; table names must follow reports_YYYYMMDD format.

-- activate event scheduler
SET GLOBAL event_scheduler = ON;

-- config pruning table: in this table is stored the value of days intervakl for pruning
DROP TABLE IF EXISTS config_pruning;
CREATE TABLE IF NOT EXISTS config_pruning (
  id INT PRIMARY KEY DEFAULT 1,
  retention_days INT NOT NULL DEFAULT 30,
  CONSTRAINT chk_retention CHECK (retention_days > 0)
);

INSERT INTO config_pruning (id, retention_days) VALUES (1, 30)
ON DUPLICATE KEY UPDATE retention_days = 30;


-- stored procedure for dropping old tables
DELIMITER //

CREATE PROCEDURE sp_prune_reports(IN retention_days INT)
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE tname VARCHAR(64);

  DECLARE cur CURSOR FOR
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
      AND table_name LIKE 'reports\_%'
      AND STR_TO_DATE(SUBSTRING(table_name, 9), '%Y%m%d') IS NOT NULL
      AND STR_TO_DATE(SUBSTRING(table_name, 9), '%Y%m%d')
            < (CURDATE() - INTERVAL retention_days DAY);

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  loop_tables: LOOP
    FETCH cur INTO tname;
    IF done THEN LEAVE loop_tables; END IF;

    SET @sql = CONCAT('DROP TABLE IF EXISTS `', REPLACE(tname, '`','``'), '`');
    PREPARE s FROM @sql;
    EXECUTE s;
    DEALLOCATE PREPARE s;
  END LOOP;

  CLOSE cur;
END//

DELIMITER ;

-- daily event calling the pruning procedure
DROP EVENT IF EXISTS ev_daily_prune_reports;

DELIMITER $$

CREATE EVENT ev_daily_prune_reports
  ON SCHEDULE EVERY 1 DAY
  STARTS CURRENT_DATE + INTERVAL 9 HOUR
  DO
  BEGIN
    DECLARE v_retention INT;
    SELECT retention_days INTO v_retention FROM config_pruning WHERE id = 1;
    CALL sp_prune_reports(v_retention);
  END$$

DELIMITER ;

-- this select is for testing purposes only, to see which tables would be dropped:
-- FROM information_schema.tables
-- WHERE table_schema = DATABASE()
--   AND table_name LIKE 'reports\_%'
--   AND STR_TO_DATE(SUBSTRING(table_name, 9), '%Y%m%d') IS NOT NULL
--   AND STR_TO_DATE(SUBSTRING(table_name, 9), '%Y%m%d') < (CURDATE() - INTERVAL 14 DAY)
-- ORDER BY table_name;