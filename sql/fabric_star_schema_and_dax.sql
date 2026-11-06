-- =============================================================================
-- Microsoft Fabric OneLake Gold Warehouse & Power BI Direct Lake Semantic Model
-- Star Schema DDL, SQL Joins & CTEs, and Governed DAX Measure Definitions
-- =============================================================================

-- 1. Gold Cohort & Revenue Retention Analytical View (SQL Joins & CTEs)
WITH quarterly_mrr_bridge AS (
    SELECT
        a.account_id,
        a.segment,
        a.industry,
        a.region,
        m.fiscal_quarter,
        m.starting_mrr,
        m.expansion_mrr,
        m.contraction_mrr,
        m.churn_mrr,
        m.ending_mrr,
        (m.ending_mrr * 12.0) AS ending_arr
    FROM dim_accounts a
    INNER JOIN fct_revenue_mrr_movements m
        ON a.account_id = m.account_id
),
account_usage_health AS (
    SELECT
        u.account_id,
        AVG(CAST(u.active_seats AS FLOAT) / NULLIF(a.provisioned_seats, 0)) AS seat_utilization_ratio,
        AVG(CAST(u.ai_copilot_active_users AS FLOAT) / NULLIF(u.active_seats, 0)) AS copilot_adoption_ratio,
        AVG(CAST(u.metered_compute_units AS FLOAT) / NULLIF(a.committed_monthly_units, 0)) AS consumption_burn_ratio
    FROM fct_product_usage_telemetry u
    INNER JOIN dim_accounts a
        ON u.account_id = a.account_id
    GROUP BY u.account_id
)
SELECT
    q.segment,
    q.region,
    q.fiscal_quarter,
    COUNT(DISTINCT q.account_id) AS active_accounts,
    SUM(q.ending_arr) AS total_ending_arr,
    ((SUM(q.starting_mrr) + SUM(q.expansion_mrr) - SUM(q.contraction_mrr) - SUM(q.churn_mrr))
        / NULLIF(SUM(q.starting_mrr), 0)) * 100.0 AS net_revenue_retention_pct,
    ((SUM(q.starting_mrr) - SUM(q.contraction_mrr) - SUM(q.churn_mrr))
        / NULLIF(SUM(q.starting_mrr), 0)) * 100.0 AS gross_revenue_retention_pct,
    AVG(h.seat_utilization_ratio) * 100.0 AS avg_seat_utilization_pct,
    AVG(h.copilot_adoption_ratio) * 100.0 AS avg_copilot_adoption_pct,
    AVG(h.consumption_burn_ratio) * 100.0 AS avg_consumption_burn_pct
FROM quarterly_mrr_bridge q
LEFT JOIN account_usage_health h
    ON q.account_id = h.account_id
GROUP BY q.segment, q.region, q.fiscal_quarter;

/* =============================================================================
   Power BI Direct Lake Semantic Model — Governed DAX Measures
   =============================================================================

   Ending ARR =
   SUM(fct_revenue_mrr_movements[ending_mrr]) * 12

   Net Revenue Retention (NRR %) =
   VAR StartMRR = SUM(fct_revenue_mrr_movements[starting_mrr])
   VAR NetEndMRR =
       StartMRR
       + SUM(fct_revenue_mrr_movements[expansion_mrr])
       - SUM(fct_revenue_mrr_movements[contraction_mrr])
       - SUM(fct_revenue_mrr_movements[churn_mrr])
   RETURN
       DIVIDE(NetEndMRR, StartMRR, 0)

   Gross Revenue Retention (GRR %) =
   VAR StartMRR = SUM(fct_revenue_mrr_movements[starting_mrr])
   VAR RetainedMRR =
       StartMRR
       - SUM(fct_revenue_mrr_movements[contraction_mrr])
       - SUM(fct_revenue_mrr_movements[churn_mrr])
   RETURN
       DIVIDE(RetainedMRR, StartMRR, 0)

   Seat Utilization % =
   DIVIDE(
       AVERAGE(fct_product_usage_telemetry[active_seats]),
       AVERAGE(dim_accounts[provisioned_seats]),
       0
   )

   Sales Pipeline Velocity ($/Day) =
   VAR QualifiedOpps = DISTINCTCOUNT(dim_crm_opportunities[opportunity_id])
   VAR AvgACV = AVERAGE(dim_crm_opportunities[acv_amount])
   VAR WinRate = DIVIDE(CALCULATE(COUNTROWS(dim_crm_opportunities), dim_crm_opportunities[is_won] = 1), COUNTROWS(dim_crm_opportunities), 0)
   VAR AvgCycleDays = AVERAGE(dim_crm_opportunities[sales_cycle_days])
   RETURN
       DIVIDE(QualifiedOpps * AvgACV * WinRate, AvgCycleDays, 0)
*/
