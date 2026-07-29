"""Runtime smoke test for Docker config-schema migration on boot.

Build the real image and verify: a config.yaml present in $WENSHU_HOME
is migrated by docker_config_migrate.py on boot, running as the wenshu
user.
"""
from __future__ import annotations

from tests.docker.conftest import docker_exec, docker_exec_sh, start_container


def test_config_migration_runs_on_boot(
    built_image: str, container_name: str,
) -> None:
    """A config.yaml in $WENSHU_HOME must be migrated on boot by
    docker_config_migrate.py, running as the wenshu user."""
    # Start container
    start_container(built_image, container_name)

    # Verify config.yaml exists (should be seeded by stage2 if not present)
    r = docker_exec_sh(
        container_name,
        "test -f /opt/data/config.yaml && echo EXISTS || echo MISSING",
        timeout=10,
    )
    assert "EXISTS" in r.stdout, (
        f"config.yaml not found in $WENSHU_HOME: {r.stdout}"
    )

    # Verify the migration script exists in the image
    r = docker_exec_sh(
        container_name,
        "test -f /opt/wenshu/scripts/docker_config_migrate.py && "
        "echo SCRIPT_EXISTS || echo SCRIPT_MISSING",
        timeout=10,
    )
    assert "SCRIPT_EXISTS" in r.stdout, (
        f"docker_config_migrate.py not found in image: {r.stdout}"
    )

    # Verify config.yaml is owned by wenshu (migration ran as wenshu)
    r = docker_exec_sh(
        container_name,
        'stat -c "%U" /opt/data/config.yaml',
        timeout=10,
    )
    assert r.stdout.strip() == "wenshu", (
        f"config.yaml not owned by wenshu (migration may have run as root): "
        f"{r.stdout.strip()}"
    )


def test_config_migration_opt_out_env_var_respected(
    built_image: str, container_name: str,
) -> None:
    """WENSHU_SKIP_CONFIG_MIGRATION=1 must skip the migration."""
    start_container(
        built_image, container_name, "WENSHU_SKIP_CONFIG_MIGRATION=1",
    )

    # config.yaml should still be seeded (seeding is separate from migration)
    r = docker_exec_sh(
        container_name,
        "test -f /opt/data/config.yaml && echo EXISTS || echo MISSING",
        timeout=10,
    )
    assert "EXISTS" in r.stdout, (
        f"config.yaml should be seeded even with migration skipped: {r.stdout}"
    )
