from functools import cached_property
from pathlib import Path
import click
import yaml


class DAP:
    """ Automate the setup of data products """
    CONFIG_FILE = Path('config.yml')

    def __init__(self, sqls_path=Path(__file__).parent.parent / 'sqls'):
        #: Path to SQL templates
        self.sqls_path = sqls_path

    @cached_property
    def config(self):
        if not self.CONFIG_FILE.exists():
            exit('config.yml does not exist in current directory. Please run "dap setup" to generate')

        with self.CONFIG_FILE.open() as fp:
            return yaml.load(fp)

    def setup(self):
        """ Setup configuration file for data products """
        if (self.CONFIG_FILE.exists()
                and not click.confirm(str(self.CONFIG_FILE) + ' exists. Do you want to override it?')):
            return

        url = click.prompt('Enter your Metabase URL')
        username = click.prompt('Enter your Metabase username')
        password = click.prompt('Enter your Metabase password', confirmation_prompt=True, hide_input=True)

        schema = click.prompt('Enter your Stripe schema name')

        # Write the YAML file
        setup_dict = {'metabase': {'url': url, 'username': username, 'password': password},
                      'stripe': {'schema': schema}}

        with self.CONFIG_FILE.open('w') as file:
          yaml.dump(setup_dict, file)

        print('Created config.yml')

    def create(self):
        """ Create data products based on configuration file. """
        print('TODO: Creating models')
        for folder in self.sqls_path.iterdir():
            for file in folder.glob('*.sql'):
                print('\t- Created Metabase model', file.name.split('.')[0])

        print('TODO: Creating questions with CSV sharing on')
        print('TODO: Creating GSheet financial model from template')
