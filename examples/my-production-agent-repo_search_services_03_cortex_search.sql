-- Step 3: Cortex Search Unstructured Indexing
USE DATABASE <% ctx.var.database_name %>;
USE SCHEMA <% ctx.var.schema_name %>;

-- Source table for unstructured documents (e.g., product manuals)
CREATE TABLE IF NOT EXISTS product_knowledge_base (
    doc_id VARCHAR(50),
    chunk_text VARCHAR(4000),
    category VARCHAR(100)
);

CREATE OR REPLACE CORTEX SEARCH SERVICE product_knowledge_search
  ON chunk_text
  ATTRIBUTES category
  WAREHOUSE = <% ctx.target.warehouse %>
  TARGET_LAG = '1 hour'
  AS (
    SELECT chunk_text, category, doc_id FROM product_knowledge_base
  );
