-- =========================================================
-- AI Annotation Project - SLA Compliance Analysis
-- Target DB: PostgreSQL (mostly compatible with MySQL)
-- =========================================================


-- ---------------------------------------------------------
-- 1) Task-level SLA evaluation
--
-- SLA definition:
--   A task meets SLA if completed within 2 days
--   from the assigned_date
-- ---------------------------------------------------------
SELECT
  task_id,
  project_id,
  assigned_date,
  completed_date,
  CASE
    WHEN completed_date IS NULL THEN NULL
    WHEN completed_date <= assigned_date + INTERVAL '2 days' THEN 1
    ELSE 0
  END AS sla_met
FROM annotation_tasks;


-- ---------------------------------------------------------
-- 2) Project-level SLA compliance summary
--
-- Metrics:
--   - total_tasks
--   - sla_met_tasks
--   - sla_compliance_rate_pct
-- ---------------------------------------------------------
SELECT
  project_id,
  COUNT(*) AS total_tasks,
  SUM(
    CASE
      WHEN completed_date <= assigned_date + INTERVAL '2 days'
      THEN 1 ELSE 0
    END
  ) AS sla_met_tasks,
  ROUND(
    100.0 * SUM(
      CASE
        WHEN completed_date <= assigned_date + INTERVAL '2 days'
        THEN 1 ELSE 0
      END
    ) / NULLIF(COUNT(*), 0),
    2
  ) AS sla_compliance_rate_pct
FROM annotation_tasks
WHERE completed_date IS NOT NULL
GROUP BY project_id
ORDER BY sla_compliance_rate_pct ASC;


-- ---------------------------------------------------------
-- 3) SLA compliance vs. project delivery delay
--
-- Purpose:
--   Examine whether low SLA compliance is associated
--   with project-level delivery delays
-- ---------------------------------------------------------
WITH sla_metrics AS (
  SELECT
    project_id,
    ROUND(
      100.0 * SUM(
        CASE
          WHEN completed_date <= assigned_date + INTERVAL '2 days'
          THEN 1 ELSE 0
        END
      ) / NULLIF(COUNT(*), 0),
      2
    ) AS sla_compliance_rate_pct
  FROM annotation_tasks
  WHERE completed_date IS NOT NULL
  GROUP BY project_id
)
SELECT
  p.project_id,
  p.project_name,
  p.vendor_name,
  p.annotation_type,
  p.planned_end_date,
  p.actual_end_date,
  CASE
    WHEN p.actual_end_date IS NULL THEN NULL
    WHEN p.actual_end_date > p.planned_end_date THEN 1
    ELSE 0
  END AS is_delayed,
  COALESCE(s.sla_compliance_rate_pct, 0) AS sla_compliance_rate_pct
FROM projects p
LEFT JOIN sla_metrics s
  ON p.project_id = s.project_id
WHERE p.actual_end_date IS NOT NULL
ORDER BY is_delayed DESC, sla_compliance_rate_pct ASC;
