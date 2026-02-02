## Daily Completed Tasks
SELECT
  project_id,
  completed_date,
  COUNT(*) AS completed_tasks
FROM annotation_tasks
WHERE completed_date IS NOT NULL
GROUP BY project_id, completed_date
ORDER BY project_id, completed_date;

## Weekly Completed Tasks
SELECT
  project_id,
  DATE_TRUNC('week', completed_date) AS week_start,
  COUNT(*) AS completed_tasks
FROM annotation_tasks
WHERE completed_date IS NOT NULL
GROUP BY project_id, DATE_TRUNC('week', completed_date)
ORDER BY project_id, week_start;

## Lower Throughput Symptoms (week-over-week)
WITH weekly AS (
  SELECT
    project_id,
    DATE_TRUNC('week', completed_date) AS week_start,
    COUNT(*) AS completed_tasks
  FROM annotation_tasks
  WHERE completed_date IS NOT NULL
  GROUP BY project_id, DATE_TRUNC('week', completed_date)
)
SELECT
  project_id,
  week_start,
  completed_tasks,
  completed_tasks
    - LAG(completed_tasks) OVER (
        PARTITION BY project_id
        ORDER BY week_start
      ) AS week_over_week_change
FROM weekly
ORDER BY project_id, week_start;



