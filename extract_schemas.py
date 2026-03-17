import json

contract_file = "backend/openapi_generated.json"
with open(contract_file, "r", encoding="utf-8") as f:
    api = json.load(f)

schemas = api.get("components", {}).get("schemas", {})

with open("schemas_dump.txt", "w", encoding="utf-8") as f:
    for name, schema in schemas.items():
        if "properties" not in schema:
            continue
        f.write(f"\n--- {name} ---\n")
        reqs = schema.get("required", [])
        for prop, info in schema["properties"].items():
            t = info.get("type")
            is_optional = False
            # OpenAPI 3.1 anyOf null check
            if "anyOf" in info:
                types = [x.get("type") for x in info["anyOf"]]
                if "null" in types:
                    is_optional = True
                t = next((x for x in types if x != "null"), t)

            if info.get("nullable", False):
                is_optional = True

            is_req = prop in reqs

            f.write(f"  {prop}: {t} (required: {is_req}, nullable: {is_optional})\n")
