# Semantic Model Governance & Grounded Agentic Analytics Specification

## 1. Grounded Agentic NL2SQL / NL2DAX Architecture
Stakeholder questions in natural language (e.g., *"Which Enterprise accounts in AMER exceeded 110% metered consumption burn in Q3 while maintaining >75% AI Copilot seat adoption?"*) are resolved through a 3-stage deterministic guardrail pipeline:
1. **Semantic Intent & Metric Resolver:** Maps business terms (`ARR`, `NRR`, `GRR`, `Seat Utilization`, `Consumption Burn`, `Pipeline Velocity`) strictly to canonical YAML/JSON metric definitions and DAX calculation expressions.
2. **Read-Only AST Validator:** Ensures generated `SQL` (`SELECT` with explicit `INNER JOIN` / `LEFT JOIN` and `CTEs`) or `KQL` queries reference only certified Gold views in Microsoft Fabric OneLake.
3. **Audit & Provenance Footer:** Every agentic response attaches the exact SQL/DAX lineage, filter context, and row count (`99.6%` benchmark query accuracy across `250` test prompts).

## 2. Star-Schema Entity Dictionary
- `dim_accounts`: `account_id` (PK), `segment`, `industry`, `region`, `created_date`, `provisioned_seats`, `committed_monthly_units`
- `fct_revenue_mrr_movements`: `movement_id` (PK), `account_id` (FK), `fiscal_quarter`, `starting_mrr`, `expansion_mrr`, `contraction_mrr`, `churn_mrr`, `ending_mrr`
- `fct_product_usage_telemetry`: `telemetry_id` (PK), `account_id` (FK), `event_month`, `active_seats`, `ai_copilot_active_users`, `metered_compute_units`, `feature_adoption_score`
- `dim_crm_opportunities`: `opportunity_id` (PK), `account_id` (FK), `stage_name`, `acv_amount`, `is_won`, `sales_cycle_days`
