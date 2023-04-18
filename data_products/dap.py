from pathlib import Path


class DAP:
    """ Automate the setup of data products """
    def __init__(self, sqls_path=Path(__file__).parent.parent / 'sqls'):
        #: Path to SQL templates
        self.sqls_path = sqls_path

    def setup(self):
        """ Setup configuration file for data products """
        # TODO:
        print('TODO: Ask for Metabase url and credentials')
        print('TODO: Ask for schema info for Stripe tables from Fivetran')
        print('TODO: Query the tables and pull in info to configure price/product')
        print('TODO: Created config.yml')

    def create(self):
        """ Create data products based on configuration file. """
        print('TODO: Read config.yml')

        print('TODO: Creating models')
        for folder in self.sqls_path.iterdir():
            for file in folder.glob('*.sql'):
                print('\t- Created Metabase model', file.name.split('.')[0])

        print('TODO: Creating questions with CSV sharing on')
        print('TODO: Creating GSheet financial model from template')
