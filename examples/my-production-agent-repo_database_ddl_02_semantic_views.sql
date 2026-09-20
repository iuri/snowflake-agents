-- Step 2: Cortex Analyst Semantic Layer
USE DATABASE <% ctx.var.database_name %>;
USE SCHEMA <% ctx.var.schema_name %>;

CREATE OR REPLACE SEMANTIC VIEW sales_analyst_layer
AS 
SELECT * FROM sales_data
COMMENT = '{"name": "sales_model", "tables": [{"name": "sales_data", "description": "Contains revenue, region, and transaction details for sales tracking."}]}';
