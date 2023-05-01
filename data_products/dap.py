from collections import defaultdict
from functools import cached_property
from pathlib import Path
import re
from uuid import uuid4

import click
import yaml

from data_products.metabase_client import MetabaseClient


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

    def save_config(self, config, **update):
        config.update(update)
        with self.CONFIG_FILE.open('w') as file:
          yaml.dump(config, file)

    def setup(self):
        """ Setup configuration file for data products """
        try:
            config = self.config
        except Exception:
            config = {}

        url = click.prompt('Enter your Metabase URL', default=config.get('metabase', {}).get('url'))
        username = click.prompt('Enter your Metabase username', default=config.get('metabase', {}).get('username'))
        password = click.prompt('Enter your Metabase password', confirmation_prompt=True, hide_input=True)

        schema = click.prompt('Enter your Stripe schema name ingested by Fivetran',
                              default=config.get('stripe', {}).get('schema'))
        db = click.prompt('Enter the database connection name in Metabase that contains the Stripe schema',
                          default=config.get('stripe', {}).get('db'))

        collection = click.prompt('Enter the Metabase collection to save new models/questions to',
                                  default=config.get('models', {}).get('collection'))

        mb_client = MetabaseClient(url, username, password)
        try:
            db_id = [d['id'] for d in mb_client.get('database')['data'] if d['name'] == db][0]

        except IndexError:
            exit(f'Could not find a database connection matching "{db}". Please try again with the correct name.')

        rows = mb_client.query(db_id, f"select id, name from {schema}.product")
        products = defaultdict(dict)
        for row in rows:
            products[row[0]]['name'] = row[1]
            products[row[0]]['is_main_product'] = True

        if not url.endswith('/'):
            url += '/'

        # Write the YAML file
        setup_dict = {'metabase': {'url': url, 'username': username, 'password': password},
                      'stripe': {'schema': schema, 'db': db, 'db_id': db_id, 'products': dict(products)},
                      'models': {'collection': collection}
                      }

        if (self.CONFIG_FILE.exists()
                and not click.confirm(f'{self.CONFIG_FILE} exists. Do you want to override it?')):
            return

        self.save_config(setup_dict)
        print(f'Created {self.CONFIG_FILE} with a list of all Stripe products.\n')
        print('Please edit it to update the Stripe product names and indicate if it is a main product or not.\n'
              'A main product will be included in the financial reports while other products will be\n'
              'collapsed and aggregated as part of the main product in the same subscription')

    def create(self, force=False, model=None):
        """ Create data products based on configuration file. """
        self._create_models(force=force, model=model)

        print('\nPlease copy the CSV URL above and '
              'paste into the Input URLs tab of the Financial Model template at ...')
        # create_excel(csv_url=self.config['test_data']['csv_url'])

    def _create_models(self, force=False, model=None):
        """ Create Metabase models """
        mb_client = MetabaseClient(self.config['metabase']['url'], self.config['metabase']['username'],
                                   self.config['metabase']['password'])

        print('Creating models')

        try:
            collection_id = [c['id'] for c in mb_client.get('collection')
                             if c['name'] == self.config['models']['collection']][0]
            print('\t* Reusing existing collection', self.config['models']['collection'], 'at',
                  self.config['metabase']['url'] + f'collection/{collection_id}')

        except IndexError:
            resp = mb_client.post('collection', json={'name': self.config['models']['collection'],
                                                      'color': '#509EE3'})
            collection_id = resp['id']
            print('\t* Created new collection', self.config['models']['collection'], 'at',
                  self.config['metabase']['url'] + f'collection/{collection_id}')

        resp = mb_client.get(f'collection/{collection_id}/items')
        existing_models = dict((i['name'], i['id']) for i in resp['data'])

        # Generate dependencies
        sql_dependencies = defaultdict(set)
        for file in self.sqls_path.glob('**/*.sql'):
            sql_dependencies[file] = self._extract_dependencies_from_sql(file.open().read())

        products_names = []
        products_mains = []
        for product_id, product in self.config['stripe']['products'].items():
            products_names.append(f"""when product.id = '{product_id}' then '{product["name"]}'""")
            products_mains.append(f"""when product.id = '{product_id}' then """
                                  f"""{str(product["is_main_product"]).lower()}""")

        created = {'stripe_schema': self.config['stripe']['schema'],
                   'stripe_product_names': '\n        '.join(products_names),
                   'stripe_product_mains': '\n        '.join(products_mains)
                   }
        models = {}

        def ref_id(model_id, model_ref):
            return f'#{model_id}-{model_ref}'.replace('_', '-')

        while sql_dependencies:
            for file in sql_dependencies:
                if sql_dependencies[file].issubset(created):
                    break  # Found one with all dependencies satisified, so we can create it.

            else:
                exit(f'ERROR: Unable to create model for {file.name} due to missing dependencies: '
                     + ', '.join(sql_dependencies[file] - set(created)))

            ref_name = file.name.split('.')[0]
            name = ref_name.replace('_', ' ').title().replace('Arr', 'ARR').replace('And', 'and')
            model_id = existing_models.get(name)
            is_public_question = '/public/' in str(file)
            is_model = not is_public_question
            model_or_question = 'model' if is_model else 'question'

            if model_id and not force:
                print('\t* Model', name, 'already exists. Use --force to update it')

                if is_public_question:
                    resp = mb_client.post(f'card/{model_id}/public_link')
                    uuid = resp['uuid']
                    print('\t- Publicly shared at',
                          self.config['metabase']['url'] + f'public/question/{uuid}.csv')

                sql_dependencies.pop(file)
                created[ref_name] = '{{' + ref_id(model_id, ref_name) + '}}'
                models[ref_name] = model_id
                continue

            template_tags = {}
            for dependent in sql_dependencies[file]:
                if dependent in models:
                    hash_model_id = ref_id(models[dependent], dependent)
                    template_tags[hash_model_id] = {
                      "type": "card",
                      "name": hash_model_id,
                      "id": str(uuid4()),
                      "display-name": hash_model_id.replace('-', ' ').title(),
                      "card-id": models[dependent]
                    }
            model_json = {
              "name": name,
              "dataset": is_model,
              "dataset_query": {
                "type": "native",
                "native": {
                  "query": Path(file).open().read().format(**created),
                  "template-tags": template_tags
                },
                "database": self.config['stripe']['db_id']
              },
              "display": "table",
              "description": None,
              "visualization_settings": {},
              "collection_id": collection_id,
            }

            if model_id:
                mb_client.put(f'card/{model_id}', json=model_json)
                if is_model:
                    mb_client.post(f'card/{model_id}/refresh', skip_return=True)
                print(f'\t* Updated existing {model_or_question}', name, 'at',
                      self.config['metabase']['url'] + f'{model_or_question}/{model_id}')

            else:
                resp = mb_client.post('card', json=model_json)
                model_id = resp['id']
                print(f'\t* Created new {model_or_question}', name, 'at',
                      self.config['metabase']['url'] + f'{model_or_question}/{model_id}')

            # Turn on public sharing
            if is_public_question:
                resp = mb_client.post(f'card/{model_id}/public_link')
                uuid = resp['uuid']
                print('\t- Publicly shared at',
                      self.config['metabase']['url'] + f'public/question/{uuid}.csv')

            sql_dependencies.pop(file)
            created[ref_name] = '{{' + ref_id(model_id, ref_name) + '}}'
            models[ref_name] = model_id

            if ref_name == model:
                exit()

    def _extract_dependencies_from_sql(self, sql):
        """ Return a set of formatted variable names (e.g. {key}) from the given SQL """
        regex = re.compile(r'{(\w+)}')
        return set(regex.findall(sql))
