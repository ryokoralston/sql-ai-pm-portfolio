SELECT
  project_id,
  planned_end_date,
  actual_end_date,
  CASE
    WHEN actual_end_date > planned_end_date THEN 1
    ELSE 0
  END AS is_delayed
FROM projects;
