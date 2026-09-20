# Snowflake Agent Studio CI/CD Deployment Guide

This document captures the complete architectural blueprint, file structures, configuration files, and CI/CD pipelines required to safely promote a **Snowflake Agent Studio** configuration (including Cortex Agents, Cortex Analyst semantic views, and Cortex Search dependencies) from **DEV** to **PROD** environments.

---

## 1. CI/CD Architecture Process Flow

```
       [ Developer Workspace ]
                  │
                  ▼  git push / merge
        ┌───────────────────┐
        │    GitHub Repo    │◄─── (Stores snowflake.yml, specs, DDLs)
        └─────────┬─────────┘
                  │
                  ▼  triggers workflow
     ┌─────────────────────────┐
     │  GitHub Actions Runner  │
     │                         │
     │ 1. Checks out repo code │
     │ 2. Sets up Snowflake CLI│
     │ 3. Injects OIDC Secrets │
     └────────────┬────────────┘
                  │
        ┌─────────┴─────────┐
        │   Snowflake CLI   │─── (Injects variables like <% ctx.var.database_name %>)
        └────┬───────────┬──┘
             │           │
   --target dev          │ --target prod
             │           │
             ▼           ▼
   ┌─────────────────┐ ┌─────────────────┐
   │ DEV Environment │ │ PROD Environment│
   │ (dev_db)        │ │ (prod_db)       │
   ├─────────────────┤ ├─────────────────┤
   │ 1. DDL Tables   │ │ 1. DDL Tables   │
   │ 2. Semantic View│ │ 2. Semantic View│
   │ 3. Search Index │ │ 3. Search Index │
   │ 4. Network Rules│ │ 4. Network Rules│
   │ 5. Cortex Agent │ │ 5. Cortex Agent │
   └─────────────────┘ └─────────────────┘
            ▲                   ▲
            │                   │
   [ Developers Test ]   [ Live Users / APIs ]
```

---

## 2. Infrastructure Configuration File (`snowflake.yml`)

This file dynamically dictates how paths and names expand depending on your environment target (`--target dev` or `--target prod`).

```yaml
definition_version: '2.0'

# Global application variables
vars:
  agent_name: sales_copilot

# Target Environment Definitions
targets:
  dev:
    account: dev_account_locator
    role: DEV_ENGINEER_ROLE
    warehouse: DEV_WH
    vars:
      database_name: DEV_DB
      schema_name: SALES_ANALYTICS
      search_service_name: DEV_DOCS_INDEX
      semantic_view_name: DEV_SALES_SEMANTIC_MODEL
  prod:
    account: prod_account_locator
    role: PROD_RELEASE_ROLE
    warehouse: PROD_WH
    vars:
      database_name: PROD_DB
      schema_name: SALES_ANALYTICS
      search_service_name: PROD_DOCS_INDEX
      semantic_view_name: PROD_SALES_SEMANTIC_MODEL

# Object definitions mapping
mixins:
  agent_setup:
    database: "<% ctx.var.database_name %>"
    schema: "<% ctx.var.schema_name %>"
```

---

## 3. Core Database Objects (`database_ddl/01_tables.sql`)

```sql
-- Create operational schemas dynamically using injected environment context
CREATE DATABASE IF NOT EXISTS <% ctx.var.database_name %>;
CREATE SCHEMA IF NOT EXISTS <% ctx.var.database_name %>.<% ctx.var.schema_name %>;

USE DATABASE <% ctx.var.database_name %>;
USE SCHEMA <% ctx.var.schema_name %>;

-- Core Sales Analytics Table for Structured Inquiries
CREATE TABLE IF NOT EXISTS customer_orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_name VARCHAR(100),
    product_category VARCHAR(50),
    order_date DATE,
    revenue NUMBER(12,2),
    region VARCHAR(30)
);

-- Internal unstructured repository stage for PDFs, contracts, manuals
CREATE STAGE IF NOT EXISTS documentation_stage 
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY = (ENABLE = TRUE);
```

---

## 4. Semantic Analytics Layer (`database_ddl/02_semantic_views.sql`)

```sql
USE DATABASE <% ctx.var.database_name %>;
USE SCHEMA <% ctx.var.schema_name %>;

-- Expose the layout layer mapping structure directly to Cortex Analyst
CREATE OR REPLACE SEMANTIC VIEW <% ctx.var.semantic_view_name %>
AS
SELECT 
    order_id, 
    customer_name, 
    product_category, 
    order_date, 
    revenue, 
    region 
FROM customer_orders;
```

---

## 5. Hybrid Unstructured Search Services (`search_services/03_cortex_search.sql`)

```sql
USE DATABASE <% ctx.var.database_name %>;
USE SCHEMA <% ctx.var.schema_name %>;

-- Deploy native search architecture to power RAG document lookup skills
CREATE OR REPLACE CORTEX SEARCH SERVICE <% ctx.var.search_service_name %>
  ON relative_path
  ATTRIBUTES region, product_category
  WAREHOUSE = <% ctx.warehouse %>
  TARGET_LAG = '1 hour'
  AS (
    SELECT 
        relative_path,
        scoped_local_url,
        file_content
    FROM DIRECTORY(@documentation_stage)
  );
```

---

## 6. Egress Isolation Layer (`tools/network_rules.sql`)

```sql
USE DATABASE <% ctx.var.database_name %>;
USE SCHEMA <% ctx.var.schema_name %>;

-- Establish outbound secure traffic parameters for custom external agent skills
CREATE OR REPLACE NETWORK RULE external_api_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('api.github.com:443', 'api.salesforce.com:443');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION secure_agent_egress_integration
  ALLOWED_NETWORK_RULES = (external_api_network_rule)
  ENABLED = TRUE;
```

---

## 7. Agent Studio Core Manifest (`agents/sales_agent_spec.yaml`)

```yaml
name: "<% ctx.var.agent_name %>"
description: "Cross-functional sales assistant executing hybrid queries across structured metrics and manuals."
role: "<% ctx.role %>"
warehouse: "<% ctx.warehouse %>"

# Core Prompt and Behavioral Blueprint Mapping
prompt_template: |
  You are an advanced enterprise analytics assistant helping teams interrogate sales pipelines.
  - For tabular questions involving numbers, metrics, revenue, and trends, use the cortex_analyst tool.
  - For unstructured policy queries, reference manuals, or catalog lookup, use the cortex_search tool.

# Mapped Tools and Dependencies
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      description: "Use this tool to discover metrics, revenue values, aggregates, and order records."
    tool_resources:
      semantic_model:
        semantic_view: "<% ctx.var.database_name %>.<% ctx.var.schema_name %>.<% ctx.var.semantic_view_name %>"

  - tool_spec:
      type: cortex_search
      name: "<% ctx.var.database_name %>.<% ctx.var.schema_name %>.<% ctx.var.search_service_name %>"
      description: "Use this tool to find documentation, catalog rules, and policy guidelines from corporate PDFs."
```
