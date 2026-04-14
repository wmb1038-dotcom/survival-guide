"""Command-line interface for awareness."""

from __future__ import annotations

import click

from . import db, config


@click.group()
def cli() -> None:
    """Oahu maritime awareness — local AIS tracker."""


@cli.command()
def init() -> None:
    """Initialise the database and print where it lives."""
    path = db.init()
    click.echo(f"✓  Database ready:  {path}")
    click.echo(f"   Config path:     {config.CONFIG_PATH}")

    cfg = config.load()
    if not cfg.key_set:
        click.secho(
            "   ⚠  No AIS Stream key found.  "
            f"Copy config.example.toml → {config.CONFIG_PATH} and fill in your key.",
            fg="yellow",
        )
    else:
        click.secho(f"   Config loaded:   {cfg}", fg="green")


@cli.command("retag")
def retag() -> None:
    """Re-classify operator for every vessel already in the database.

    Use this after updating fleet name lists or operator logic to fix existing
    rows without wiping and re-ingesting.
    """
    from .ingest_ais import retag_existing_vessels
    count = retag_existing_vessels()
    click.echo(f"Retagged {count} vessel(s).")


@cli.command("ingest-ais")
def ingest_ais() -> None:
    """Stream live AIS positions from AISStream.io into the local database.

    Runs until interrupted (Ctrl-C / SIGTERM).  Reconnects automatically on
    disconnect with exponential back-off (1 s → 2 s → … → 60 s cap).

    Requires aisstream_api_key to be set in:

        ~/Library/Application Support/awareness/config.toml

    Progress is logged to:

        ~/Library/Application Support/awareness/ingest.log
    """
    from .ingest_ais import run
    run()


@cli.command("dashboard")
def dashboard() -> None:
    """Generate a unified Folium map dashboard with maritime and water data.

    Output is saved to app_data/dashboard.html.
    """
    from scripts import generate_dashboard
    generate_dashboard.generate()


@cli.command("scrape-matson")
def scrape_matson() -> None:
    """Scrape Matson's Hawaii vessel schedule and update maritime.db."""
    from .scrape_matson import run
    run()


if __name__ == "__main__":
    cli()
