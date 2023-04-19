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
@click.option('--model', type=int, help='Stop after creating the given model id. Implies force. Useful for testing')
def create(force, model):
    if model:
        force = True

    dap = DAP()
    dap.create(force=force, model=model)
