import json
import os
import sys

from fastapi.openapi.utils import get_openapi

# Add current directory to sys.path so we can import 'app'
sys.path.append(os.getcwd())

try:
    # Attempt to import the app. If this fails due to DB connections, we might need to mock.
    from app.main import app

    # Generate schema
    schema = get_openapi(
        title=app.title,
        version=app.version,
        openapi_version=app.openapi_version,
        description=app.description,
        routes=app.routes,
    )

    # Write to file
    with open("openapi_generated.json", "w") as f:
        json.dump(schema, f, indent=2)

    print("Schema generated successfully to openapi_generated.json")

except Exception as e:
    print(f"Error generating schema: {e}", file=sys.stderr)
    import traceback

    traceback.print_exc()
