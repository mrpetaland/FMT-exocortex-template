import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "iwe-drift.sh"


def test_activity_checks_are_not_parsed_as_drift_pairs(tmp_path):
    manifest = tmp_path / "sync-manifest.yaml"
    manifest.write_text(
        """pairs:
  - id: real-pair
    source: source.md
    derived: derived.md
    relation: generated
    check: mtime
    threshold_days: 1
    critical_days: 3
    owner_role: R1
    symptom: \"real\"
activity_checks:
  - id: lesson-hygiene
    action: \"review\"
    expected_per_period: 1
    period_days: 7
    commit_pattern_regex: \"lesson\"
    dormant_after_periods: 2
""",
        encoding="utf-8",
    )
    (tmp_path / "source.md").write_text("source", encoding="utf-8")
    (tmp_path / "derived.md").write_text("derived", encoding="utf-8")

    result = subprocess.run(
        ["bash", str(SCRIPT), "--manifest", str(manifest)],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        timeout=15,
    )

    assert result.returncode == 0, result.stderr
    assert "real-pair" in result.stdout
    assert "lesson-hygiene" not in result.stdout
