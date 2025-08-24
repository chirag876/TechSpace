----------------- Works in MySQL
WITH RECURSIVE
  missing_ids AS (
    SELECT
      MIN(id) AS id
    FROM
      users
    UNION ALL
    SELECT
      id + 1
    FROM
      missing_ids
    WHERE
      id < (
        SELECT
          MAX(id)
        FROM
          users
      )
  )
SELECT
  id
FROM
  missing_ids
WHERE
  id NOT IN (
    SELECT
      id
    FROM
      users
  );