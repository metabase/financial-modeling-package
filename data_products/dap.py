from functools import cached_property
from pathlib import Path
import click

import yaml

from data_products.metabase_client import MetabaseClient
from data_products.gsheets import create_gsheets


class DAP:
    """ Automate the setup of data products """
    CONFIG_FILE = Path('config.yml')

    def __init__(self, sqls_path=Path(__file__).parent.parent / 'sqls'):
        #: Path to SQL templates
        self.sqls_path = sqls_path

    @cached_property
    def config(self):
        if not self.CONFIG_FILE.exists():
            exit(f'{self.CONFIG_FILE} does not exist in current directory. Please run "dap setup" to generate')

        with self.CONFIG_FILE.open() as fp:
            return yaml.load(fp, Loader=yaml.Loader)

    def setup(self):
        """ Setup configuration file for data products """
        if (self.CONFIG_FILE.exists()
                and not click.confirm(f'{self.CONFIG_FILE} exists. Do you want to override it?')):
            return

        url = click.prompt('Enter your Metabase URL')
        username = click.prompt('Enter your Metabase username')
        password = click.prompt('Enter your Metabase password', confirmation_prompt=True, hide_input=True)

        schema = click.prompt('Enter your Stripe schema name ingested by Fivetran')
        db = click.prompt('Enter the database connection name in Metabase that contains the Stripe schema')

        collection = click.prompt('Enter the Metabase collection to save new models/questions to')

        if not url.endswith('/'):
            url += '/'

        # Write the YAML file
        setup_dict = {'metabase': {'url': url, 'username': username, 'password': password},
                      'stripe': {'schema': schema, 'db': db},
                      'models': {'collection': collection}}

        with self.CONFIG_FILE.open('w') as file:
          yaml.dump(setup_dict, file)

        print('TODO: Ask for GSheets API credentials')

        print(f'Created {self.CONFIG_FILE} -- feel free to modify it if needed')

    def create(self):
        """ Create data products based on configuration file. """
        mb_client = MetabaseClient(self.config['metabase']['url'], self.config['metabase']['username'],
                                   self.config['metabase']['password'])

        try:
            db_id = [db['id'] for db in mb_client.get('database')['data']
                     if db['name'] == self.config['stripe']['db']][0]

        except IndexError:
            exit('Could not find a database connection matching "' + self.config['stripe']['db']
                 + f'". Please update {self.CONFIG_FILE} with the correct name in stripe -> db')

        print('Creating models')

        try:
            collection_id = [c['id'] for c in mb_client.get('collection')
                             if c['name'] == self.config['models']['collection']][0]
            print('\t- In existing collection', self.config['models']['collection'])

        except IndexError:
            resp = self.client.post('collection', json={'name': self.config['models']['collection'],
                                                        'parent_id': 'root',
                                                        'color': '#509EE3'})
            collection_id = resp['id']
            print('\t - In new collection', self.config['models']['collection'])

        for folder in self.sqls_path.iterdir():
            for file in folder.glob('*.sql'):
                name = file.name.split('.')[0].replace('_', ' ').title()
                model_json = {
                  "name": name,
                  "dataset": True,
                  "dataset_query": {
                    "type": "native",
                    "native": {
                      "query": Path(file).open().read().format(stripe_schema=self.config['stripe']['schema']),
                    },
                    "database": db_id
                  },
                  "display": "table",
                  "description": None,
                  "visualization_settings": {},
                  "collection_id": collection_id,
                }
                resp = mb_client.post('card', json=model_json)
                print('\t- Created new model', name, 'at', self.config['metabase']['url'] + 'model/' + str(resp['id']))

        print('TODO: Create more models that will be used directly in the GSheets below and save urls to config.yml')

        create_gsheets()
