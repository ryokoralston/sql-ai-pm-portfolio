-- =========================================================
-- AI Annotation Project - Delay Risk Analysis (Queries)
-- Target DB: PostgreSQL (mostly compatible with MySQL)
-- =========================================================


-- ---------------------------------------------------------
-- 0) Helper: Project delay flag and delay days
--
-- Definitions:
--   - is_delayed:
--       1 if actual_end_date is later than planned_end_date
--       0 if on time or early
--       NULL if the project is still ongoing
--
--   - delay_days:
--       Number of days delayed
--       0 if on time or early
--       NULL if the project is still ongoing
--
-- Purpose:
--   Provide a base view for identifying delayed projects
-- ---------------------------------------------------------
SELECT
  project_id,
  project_name,
  vendor_name,
  annotation_type,
  planned_start_date,
  planned_end_date,
  actual_end_date,
  CASE
    WHEN actual_end_date IS NULL THEN NULL
    WHEN actual_end_date > planned_end_date THEN 1
    ELSE 0
  END AS is_delayed,
  CASE
    WHEN actual_end_date IS NULL THEN NULL
    WHEN actual_end_date > planned_end_date THEN (actual_end_date - planned_end_date)
    ELSE 0
  END AS delay_days
FROM projects
ORDER BY planned_end_date, project_id;


-- ---------------------------------------------------------
-- 1) Overall project delay summary
--
-- Purpose:
--   Calculate overall delay rate across completed projects
--
-- Metrics:
--   - completed_projects: total number of completed projects
--   - delayed_projects: number of delayed projects
--   - delay_rate_pct: percentage of delayed projects
-- ---------------------------------------------------------
SELECT
  COUNT(*) AS completed_projects,
  SUM(CASE WHEN actual_end_date > planned_end_date THEN 1 ELSE 0 END) AS delayed_projects,
  ROUND(
    100.0 * SUM(CASE WHEN actual_end_date > planned_end_date THEN 1 ELSE 0 END)
    / NULLIF(COUNT(*), 0),
    2
  ) AS delay_rate_pct
FROM projects
WHERE actual_end_date IS NOT NULL;


-- ---------------------------------------------------------
-- 2) Delay rate by vendor
--
-- Purpose:
--   Identify vendors with higher delay rates
--
-- Metrics:
--   - completed_projects: completed projects per vendor
--   - delayed_projects: delayed projects per vendor
--   - delay_rate_pct: vendor-level delay rate
-- ---------------------------------------------------------
SELECT
  COALESCE(vendor_name, 'UNKNOWN') AS vendor_name,
  COUNT(*) AS completed_projects,
  SUM(CASE WHEN actual_end_date > planned_end_date THEN 1 ELSE 0 END) AS delayed_projects,
  ROUND(
    100.0 * SUM(CASE WHEN actual_end_date > planned_end_date THEN 1 ELSE 0 END)
    / NULLIF(COUNT(*), 0),
    2
  ) AS delay_rate_pct
FROM projects
WHERE actual_end_date IS NOT NULL
GROUP BY COALESCE(vendor_name, 'UNKNOWN')
ORDER BY delay_rate_pct DESC, completed_projects DESC;


-- ---------------------------------------------------------
-- 3) Rework vs. delay analysis
--
-- Purpose:
--   Analyze the relationship between rework activity and
--   project delivery delays
--
-- Metrics (project level):
--   - total_tasks: total annotation tasks
--   - rework_tasks: number of tasks with rework_flag = true
--   - rework_task_rate_pct: percentage of tasks requiring rework
--   - avg_rework_count: average number of reworks per task
-- ---------------------------------------------------------
WITH task_metrics AS (
  SELECT
    project_id,
    COUNT(*) AS total_tasks,
    SUM(CASE WHEN rework_flag THEN 1 ELSE 0 END) AS rework_tasks,
    ROUND(
      100.0 * SUM(CASE WHEN rework_flag THEN 1 ELSE 0 END)
      / NULLIF(COUNT(*), 0),
      2
    ) AS rework_task_rate_pct,
    ROUND(AVG(rework_count)::numeric, 2) AS avg_rework_count
  FROM annotation_tasks
  GROUP BY project_id
)
SELECT
  p.project_id,
  p.project_name,
  COALESCE(p.vendor_name, 'UNKNOWN') AS vendor_name,
  p.annotation_type,
  p.planned_end_date,
  p.actual_end_date,
  CASE
    WHEN p.actual_end_date IS NULL THEN NULL
    WHEN p.actual_end_date > p.planned_end_date THEN 1
    ELSE 0
  END AS is_delayed,
  COALESCE(t.total_tasks, 0) AS total_tasks,
  COALESCE(t.rework_tasks, 0) AS rework_tasks,
  COALESCE(t.rework_task_rate_pct, 0) AS rework_task_rate_pct,
  COALESCE(t.avg_rework_count, 0) AS avg_rework_count
FROM projects p
LEFT JOIN task_metrics t
  ON p.project_id = t.project_id
WHERE p.actual_end_date IS NOT NULL
ORDER BY is_delayed DESC, rework_task_rate_pct DESC, rework_tasks DESC;


-- ---------------------------------------------------------
-- 4) Open quality issues vs. delay analysis
--
-- Definition:
--   Open issue = resolved_date IS NULL
--
-- Purpose:
--   Evaluate whether unresolved quality issues are
--   associated with project delivery delays
--
-- Metrics (project level):
--   - total_issues: total number of quality issues
--   - open_issues: unresolved quality issues
--   - open_issue_rate_pct: percentage of unresolved issues
-- ---------------------------------------------------------
WITH issue_metrics AS (
  SELECT
    project_id,
    COUNT(*) AS total_issues,
    SUM(CASE WHEN resolved_date IS NULL THEN 1 ELSE 0 END) AS open_issues,
    ROUND(
      100.0 * SUM(CASE WHEN resolved_date IS NULL THEN 1 ELSE 0 END)
      / NULLIF(COUNT(*), 0),
      2
    ) AS open_issue_rate_pct
  FROM quality_issues
  GROUP BY project_id
)
SELECT
  p.project_id,
  p.project_name,
  COALESCE(p.vendor_name, 'UNKNOWN') AS vendor_name,
  p.annotation_type,
  p.planned_end_date,
  p.actual_end_date,
  CASE
    WHEN p.actual_end_date IS NULL THEN NULL
    WHEN p.actual_end_date > p.planned_end_date THEN 1
    ELSE 0
  END AS is_delayed,
  COALESCE(i.total_issues, 0) AS total_issues,
  COALESCE(i.open_issues, 0) AS open_issues,
  COALESCE(i.open_issue_rate_pct, 0) AS open_issue_rate_pct
FROM projects p
LEFT JOIN issue_metrics i
  ON p.project_id = i.project_id
WHERE p.actual_end_date IS NOT NULL
ORDER BY is_delayed DESC, open_issues DESC, open_issue_rate_pct DESC;
