import os
import re
import subprocess
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
SERVICES_ROOT = BACKEND_ROOT / "app" / "services"


def test_no_magic_thresholds_in_services() -> None:
    violations = []
    literal_pattern = re.compile(r'Decimal\(\s*["\']0\.05["\']\s*\)')
    days_pattern = re.compile(r"days_to_zero\s*<\s*(3|7|14)\b")

    for path in sorted(SERVICES_ROOT.rglob("*.py")):
        content = path.read_text(encoding="utf-8")
        if literal_pattern.search(content):
            rel = path.relative_to(BACKEND_ROOT).as_posix()
            violations.append(f"{rel}:Decimal(0.05)")
        if days_pattern.search(content):
            rel = path.relative_to(BACKEND_ROOT).as_posix()
            violations.append(f"{rel}:hardcoded signal day threshold")

    assert not violations, "Magic threshold literals found in services:\n" + "\n".join(
        violations
    )


def test_threshold_config_validates_env_override() -> None:
    invalid_env = os.environ.copy()
    invalid_env["DRIFT_CRITICAL_RATIO"] = "-1"
    invalid_env["FORECAST_CRITICAL_DAYS"] = "8"
    invalid_env["FORECAST_REORDER_SOON_DAYS"] = "7"
    invalid_env["FORECAST_WATCH_DAYS"] = "14"

    code = "from app.core.governance import thresholds\nprint(thresholds)\n"
    invalid_run = subprocess.run(
        [sys.executable, "-c", code],
        capture_output=True,
        text=True,
        cwd=BACKEND_ROOT,
        env=invalid_env,
    )
    assert invalid_run.returncode != 0

    default_env = os.environ.copy()
    default_env.pop("DRIFT_CRITICAL_RATIO", None)
    default_env.pop("FORECAST_CRITICAL_DAYS", None)
    default_env.pop("FORECAST_REORDER_SOON_DAYS", None)
    default_env.pop("FORECAST_WATCH_DAYS", None)

    default_code = (
        "from app.core.governance import thresholds\n"
        "print(thresholds.drift.critical_ratio)\n"
        "print(thresholds.forecast.critical_days)\n"
        "print(thresholds.forecast.reorder_soon_days)\n"
        "print(thresholds.forecast.watch_days)\n"
    )
    default_run = subprocess.run(
        [sys.executable, "-c", default_code],
        capture_output=True,
        text=True,
        check=True,
        cwd=BACKEND_ROOT,
        env=default_env,
    )
    lines = [line.strip() for line in default_run.stdout.splitlines() if line.strip()]
    assert lines[:4] == ["0.05", "3", "7", "14"]
