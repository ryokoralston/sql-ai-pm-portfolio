-- =========================================================
-- AI Annotation Project - Delay Risk Analysis (Schema)
-- Target DB: PostgreSQL (mostly compatible with MySQL)
-- Notes:
--  - This schema is intended for portfolio/demo use.
--  - You can keep it as "schema only" without inserting data.
-- =========================================================

-- Clean up (optional)
DROP TABLE IF EXISTS quality_issues;
DROP TABLE IF EXISTS annotation_tasks;
DROP TABLE IF EXISTS projects;

-- ---------------------------------------------------------
-- 1) Projects (project-level plan vs. actual)
-- ---------------------------------------------------------
CREATE TABLE projects (
  project_id            VARCHAR(50) PRIMARY KEY,
  project_name          VARCHAR(200) NOT NULL,

  vendor_name           VARCHAR(200),                 -- e.g., vendor / BPO partner
  dataset_name          VARCHAR(200),                 -- optional: dataset / client program name

  annotation_type       VARCHAR(50) NOT NULL,         -- e.g., bbox, segmentation, text, audio
  priority              VARCHAR(20) DEFAULT 'normal',  -- e.g., low, normal, high, critical

  planned_start_date    DATE NOT NULL,
  planned_end_date      DATE NOT NULL,
  actual_end_date       DATE,                         -- NULL if ongoing

  target_tasks          INTEGER NOT NULL DEFAULT 0,    -- expected number of tasks (volume)
  notes                 TEXT,

  created_at            TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Helpful indexes
CREATE INDEX idx_projects_vendor_name ON projects (vendor_name);
CREATE INDEX idx_projects_annotation_type ON projects (annotation_type);
CREATE INDEX idx_projects_planned_end_date ON projects (planned_end_date);


-- ---------------------------------------------------------
-- 2) Annotation tasks (work unit level)
-- ---------------------------------------------------------
CREATE TABLE annotation_tasks (
  task_id               VARCHAR(50) PRIMARY KEY,
  project_id            VARCHAR(50) NOT NULL REFERENCES projects(project_id),

  assigned_date         DATE NOT NULL,
  completed_date        DATE,                         -- NULL if in progress

  annotator_id          VARCHAR(50),                  -- internal or vendor worker id
  task_status           VARCHAR(30) NOT NULL DEFAULT 'assigned',
  -- suggested statuses: assigned, in_progress, completed, blocked, cancelled

  rework_flag           BOOLEAN NOT NULL DEFAULT FALSE,
  rework_count          INTEGER NOT NULL DEFAULT 0,    -- how many times reworked

  time_spent_minutes    INTEGER,                      -- optional: effort
  created_at            TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tasks_project_id ON annotation_tasks (project_id);
CREATE INDEX idx_tasks_assigned_date ON annotation_tasks (assigned_date);
CREATE INDEX idx_tasks_completed_date ON annotation_tasks (completed_date);
CREATE INDEX idx_tasks_rework_flag ON annotation_tasks (rework_flag);


-- ---------------------------------------------------------
-- 3) Quality issues (guideline/accuracy problems etc.)
-- ---------------------------------------------------------
CREATE TABLE quality_issues (
  issue_id              VARCHAR(50) PRIMARY KEY,
  project_id            VARCHAR(50) NOT NULL REFERENCES projects(project_id),

  issue_type            VARCHAR(50) NOT NULL,
  -- suggested types: guideline, accuracy, ontology, ambiguity, tooling, data_problem

  severity              VARCHAR(20) NOT NULL DEFAULT 'medium',
  -- suggested: low, medium, high, critical

  detected_date         DATE NOT NULL,
  resolved_date         DATE,                         -- NULL if open

  related_task_id       VARCHAR(50),                  -- optional link to a task
  description           TEXT,

  created_at            TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_issues_project_id ON quality_issues (project_id);
CREATE INDEX idx_issues_issue_type ON quality_issues (issue_type);
CREATE INDEX idx_issues_detected_date ON quality_issues (detected_date);
CREATE INDEX idx_issues_resolved_date ON quality_issues (resolved_date);

-- ---------------------------------------------------------
-- Optional: Basic sanity constraints (PostgreSQL only)
-- ---------------------------------------------------------
-- Ensure planned dates are sensible
ALTER TABLE projects
  ADD CONSTRAINT chk_planned_dates
  CHECK (planned_end_date >= planned_start_date);

-- Ensure counts are non-negative
ALTER TABLE projects
  ADD CONSTRAINT chk_target_tasks_nonneg
  CHECK (target_tasks >= 0);

ALTER TABLE annotation_tasks
  ADD CONSTRAINT chk_rework_count_nonneg
  CHECK (rework_count >= 0);

ALTER TABLE annotation_tasks
  ADD CONSTRAINT chk_time_spent_nonneg
  CHECK (time_spent_minutes IS NULL OR time_spent_minutes >= 0);
