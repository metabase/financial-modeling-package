import click

from data_products.dap import DAP


@click.group(help='Automate the setup of data products')
def cli():
    pass


@cli.command(help='Setup data products and create a YAML configuration file.')
def setup():
    dap = DAP()
    dap.setup()


@cli.command(help='Create data products')
@click.option('--force', is_flag=True, help='Force the creation of everything by overriding existing if needed')
def create(force):
    dap = DAP()
    dap.create(force=force)
