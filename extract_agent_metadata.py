import os
import re
import yaml
import json
from snowflake.snowpark.context import get_active_session

# --- CONFIGURATION ---
OUTPUT_DIR = "./snowflake_agents_backup"
os.makedirs(f"{OUTPUT_DIR}/agents", exist_ok=True)
os.makedirs(f"{OUTPUT_DIR}/semantic_views", exist_ok=True)
os.makedirs(f"{OUTPUT_DIR}/search_services", exist_ok=True)

def clean_filename(name):
    return re.sub(r'[\\/*?:"<>| ]', '_', name.lower())

def execute_query(session, query):
    try:
        rows = session.sql(query).collect()
        if not rows:
            return [], []
        columns = list(rows[0].asDict().keys())
        result = [tuple(row.asDict().values()) for row in rows]
        return result, columns
    except Exception as e:
        print(f"[-] Query failed: {query}\nError: {e}")
        return [], []

def main():
    print("[+] Connecting to Snowflake...")
    session = get_active_session()
    print("[+] Connected via active session.")

    # 1. Discover all accessible Cortex Agents across the Account
    print("[+] Scanning Account for Snowflake Cortex Agents...")
    agents, columns = execute_query(session, "SHOW AGENTS IN ACCOUNT;")

    if not agents:
        print("[-] No Cortex Agents found or insufficient role permissions.")
        return

    # Map column positions dynamically from SHOW AGENTS output
    col_idx = {col.lower(): i for i, col in enumerate(columns)}

    for agent in agents:
        agent_name = agent[col_idx['name']]
        db_name = agent[col_idx['database_name']]
        schema_name = agent[col_idx['schema_name']]
        fq_agent_name = f'"{db_name}"."{schema_name}"."{agent_name}"'

        print(f"\n[*] Processing Agent: {fq_agent_name}")

        # 2. Extract Agent Definition via DESCRIBE AGENT
        desc_res, desc_cols = execute_query(session, f"DESCRIBE AGENT {fq_agent_name};")
        if desc_res:
            desc_col_idx = {col.lower(): i for i, col in enumerate(desc_cols)}
            agent_filename = clean_filename(f"{db_name}_{schema_name}_{agent_name}")

            # Save full DESCRIBE output as JSON
            agent_metadata = {col: desc_res[0][i] for i, col in enumerate(desc_cols)}
            with open(f"{OUTPUT_DIR}/agents/{agent_filename}.json", "w", encoding="utf-8") as f:
                json.dump(agent_metadata, f, indent=2, default=str)

            # Extract the agent_spec field which contains the full specification
            agent_spec_raw = desc_res[0][desc_col_idx.get('agent_spec', -1)] if 'agent_spec' in desc_col_idx else None
            if agent_spec_raw:
                try:
                    spec_dict = json.loads(agent_spec_raw) if isinstance(agent_spec_raw, str) else agent_spec_raw
                except (json.JSONDecodeError, TypeError):
                    spec_dict = yaml.safe_load(agent_spec_raw) if isinstance(agent_spec_raw, str) else None

                if spec_dict:
                    with open(f"{OUTPUT_DIR}/agents/{agent_filename}_spec.yaml", "w", encoding="utf-8") as f:
                        yaml.dump(spec_dict, f, default_flow_style=False, sort_keys=False)

                    # 3. Analyze Dependencies inside the Agent Specification
                    try:
                        tools = spec_dict.get("tools", [])
                        tool_resources = spec_dict.get("tool_resources", {})

                        for tool in tools:
                            tool_spec = tool.get("tool_spec", {})
                            tool_type = tool_spec.get("type")
                            tool_name = tool_spec.get("name")

                            # Target Cortex Analyst Dependencies (Semantic Views)
                            if tool_type == "cortex_analyst_text_to_sql":
                                resource = tool_resources.get(tool_name, {})
                                semantic_view_target = resource.get("semantic_view")
                                if semantic_view_target:
                                    print(f"  [->] Dependency Detected: Semantic View ({semantic_view_target})")
                                    sv_ddl, _ = execute_query(session, f"SELECT GET_DDL('SEMANTIC VIEW', '{semantic_view_target}');")
                                    if sv_ddl:
                                        sv_filename = clean_filename(semantic_view_target)
                                        with open(f"{OUTPUT_DIR}/semantic_views/{sv_filename}.sql", "w", encoding="utf-8") as f:
                                            f.write(sv_ddl[0][0])

                            # Target Unstructured Data Dependencies (Cortex Search Services)
                            elif tool_type == "cortex_search":
                                resource = tool_resources.get(tool_name, {})
                                search_service_target = resource.get("search_service")
                                if search_service_target:
                                    print(f"  [->] Dependency Detected: Cortex Search Service ({search_service_target})")
                                    cs_ddl, _ = execute_query(session, f"SELECT GET_DDL('CORTEX_SEARCH_SERVICE', '{search_service_target}');")
                                    if cs_ddl:
                                        cs_filename = clean_filename(search_service_target)
                                        with open(f"{OUTPUT_DIR}/search_services/{cs_filename}.sql", "w", encoding="utf-8") as f:
                                            f.write(cs_ddl[0][0])

                    except Exception as y_err:
                        print(f"  [-] Could not parse agent spec dependencies: {y_err}")

    print(f"\n[+] Extraction successfully completed! All files written to: {OUTPUT_DIR}")

if __name__ == "__main__":
    main()
