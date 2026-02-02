-- =========================================================
-- AI Annotation Project - Quality Drift Analysis
-- Target DB: PostgreSQL (mostly compatible with MySQL)
-- =========================================================


-- ---------------------------------------------------------
-- 1) Weekly quality issue trend (project level)
--
-- Purpose:
--   Observe changes in quality issue volume over time
-- ---------------------------------------------------------
SELECT
  project_id,
  DATE_TRUNC('week', detected_date) AS week_start,
  COUNT(*) AS issues_detected
FROM quality_issues
GROUP BY project_id, DATE_TRUNC('week', detected_date)
ORDER BY project_id, week_start;


-- ---------------------------------------------------------
-- 2) Open issues trend over time
--
-- Definition:
--   Open issue = resolved_date IS NULL
--
-- Purpose:
--   Identify accumulation of unresolved issues
-- ---------------------------------------------------------
SELECT
  project_id,
  DATE_TRUNC('week', detected_date) AS week_start,
  SUM(
    CASE
      WHEN resolved_date IS NULL THEN 1
      ELSE 0
    END
  ) AS open_issues
FROM quality_issues
GROUP BY project_id, DATE_TRUNC('week', detected_date)
ORDER BY project_id, week_start;


-- ---------------------------------------------------------
-- 3) Drift signal: week-over-week change in issue volume
--
-- Purpose:
--   Detect sudden increases indicating instability
-- ---------------------------------------------------------
WITH weekly_issues AS (
  SELECT
    project_id,
    DATE_TRUNC('week', detected_date) AS week_start,
    COUNT(*) AS issues_detected
  FROM quality_issues
  GROUP BY project_id, DATE_TRUNC('week', detected_date)
)
SELECT
  project_id,
  week_start,
  issues_detected,
  issues_detected
    - LAG(issues_detected) OVER (
        PARTITION BY project_id
        ORDER BY week_start
      ) AS week_over_week_change
FROM weekly_issues
ORDER BY project_id, week_start;


-- ---------------------------------------------------------
-- 4) Quality drift vs. delivery delay
--
-- Purpose:
--   Examine whether projects with increasing quality issues
--   are more likely to experience delivery delays
-- ---------------------------------------------------------
WITH issue_trend AS (
  SELECT
    project_id,
    COUNT(*) AS total_issues
  FROM quality_issues
  GROUP BY project_id
)
SELECT
  p.project_id,
  p.project_name,
  p.vendor_name,
  p.annotation_type,
  CASE
    WHEN p.actual_end_date IS NULL THEN NULL
    WHEN p.actual_end_date > p.planned_end_date THEN 1
    ELSE 0
  END AS is_delayed,
  COALESCE(i.total_issues, 0) AS total_issues
FROM projects p
LEFT JOIN issue_trend i
  ON p.project_id = i.project_id
WHERE p.actual_end_date IS NOT NULL
ORDER BY is_delayed DESC, total_issues DESC;
