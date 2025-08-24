/*
-----------------------------------------------------------------------------------
Script: Identify Expensive Queries from SQL Server Plan Cache
Technology: T-SQL (Dynamic Management Views)

Purpose:
- Retrieves queries from SQL Server's plan cache.
- Identifies expensive queries by total execution time.

Features:
- Shows query text and execution plan.
- Provides execution statistics such as:
 * Execution count
 * Total CPU time (worker time)
 * Total elapsed time
 * Creation time of the query plan
 * Last execution time
- Orders results by total elapsed time (longest running queries first).

Use Cases:
- Performance tuning: find queries that consume the most time.
- Identify candidates for optimization (indexes, query rewrites).
- Understand workload patterns on the server.

Notes:
- Run this on the target SQL Server database context in SSMS.
- Results come from plan cache (data resets when SQL Server restarts).
-----------------------------------------------------------------------------------
 */
SELECT
    qs.sql_handle,
    qs.plan_handle,
    qs.execution_count,
    qs.total_worker_time,
    qs.total_elapsed_time,
    qs.creation_time,
    qs.last_execution_time,
    st.text AS query_text,
    qp.query_plan
FROM
    sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text (qs.sql_handle) st CROSS APPLY sys.dm_exec_query_plan (qs.plan_handle) qp
ORDER BY
    qs.total_elapsed_time DESC;