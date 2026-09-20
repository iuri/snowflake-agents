-- Step 1: Base Tables Setup
CREATE DATABASE IF NOT EXISTS <% ctx.var.database_name %>;
CREATE SCHEMA IF NOT EXISTS <% ctx.var.database_name %>.<% ctx.var.schema_name %>;

USE DATABASE <% ctx.var.database_name %>;
USE SCHEMA <% ctx.var.schema_name %>;

CREATE TABLE IF NOT EXISTS sales_data (
    sale_id INT,
    product_name VARCHAR(100),
    revenue NUMBER(10,2),
    region VARCHAR(50),
    sale_date DATE
);

-- Seed metadata table for Agent evaluations / Few-Shot golden queries
CREATE TABLE IF NOT EXISTS agent_golden_queries (
    user_query VARCHAR(500),
    expected_sql VARCHAR(2000),
    description VARCHAR(500)
);
