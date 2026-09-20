SELECT CURRENT_ACCOUNT();

SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();


-- SHOW AGENTS [IN SCHEMA db.schema | IN ACCOUNT]
-- returns every agent you have privileges on, with its database and schema. This is your starting inventory row.
SHOW AGENTS; 

-- SELECT GET_DDL('AGENT', 'db.schema.agent_name'); 
-- returns the entire agent_spec YAML inline — models, instructions, and every tool_resources entry (semantic views, Cortex Search services, custom tools). This single query is the authoritative source for everything the agent directly references — read it before querying anything else.
SELECT GET_DDL('CORTEX_AGENT', 'SALES_INTELLIGENCE.DATA.SALES_INTELIGENCE_AGENT'); 


-- DESCRIBE AGENT db.schema.agent_name 
-- returns owner, comment, and profile in tabular form — useful for a fast inventory pass across many agents, versus GET_DDL's full text when you need the detail on one.
DESCRIBE AGENT SALES_INTELLIGENCE.DATA.SALES_INTELIGENCE_AGENT;

-- For every tool_resources.<tool>.semantic_view found in step 2, run SELECT GET_DDL('SEMANTIC_VIEW', 'db.schema.view_name'); 
-- to see the tables/views it maps to facts and dimensions — this is where the agent's real table/view dependencies live, one level removed from the agent object itself.


--SHOW CORTEX SEARCH SERVICES [LIKE 'name'] then DESCRIBE CORTEX SEARCH SERVICE db.schema.service_name reveals the source table or view the search index was built from.


-- Drill into custom tools
-- For any tool_spec of type generic (a UDF or stored procedure), 
-- SHOW USER FUNCTIONS/PROCEDURES LIKE 'name' followed by SELECT GET_DDL('FUNCTION', 'db.schema.func_name') or GET_DDL('PROCEDURE', ...) gives the underlying code and any tables it touches.





SELECT
    "name",
    "database_name",
    "schema_name",
    PARSE_JSON("agent_spec") AS spec
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));



-- The agent itself
SHOW AGENTS IN SCHEMA SALES_INTELLIGENCE.DATA;

-- Database and schema
SHOW DATABASES LIKE 'SALES_INTELLIGENCE';
SHOW SCHEMAS IN DATABASE SALES_INTELLIGENCE;

-- Tables and views in the same schema (or referenced schemas)
SHOW TABLES IN SCHEMA SALES_INTELLIGENCE.DATA;
SHOW VIEWS IN SCHEMA SALES_INTELLIGENCE.DATA;

-- Semantic views
SHOW SEMANTIC VIEWS IN SCHEMA SALES_INTELLIGENCE.DATA;


SELECT *
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE(
    'SALES_INTELLIGENCE.DATA.SALES_INTELIGENCE_AGENT',
    'CORTEX_AGENT',
    'upstream',
    5
));