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
def create():
    dap = DAP()
    dap.create()
