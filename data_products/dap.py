from __future__ import print_function
from pathlib import Path
import json
import os.path
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# variables
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']
SAMPLE_SPREADSHEET_ID = '1O4UR4lq0eyDQZVOhwS8R3j-dwhlxxuiI7OPvBerj0-0'
SAMPLE_RANGE_NAME = 'Master URLs!A2:C10'
#this is currently hardcoded and repreents the URLs from metabase along with question title but eventually this will programatic
tabs_json = {'Self Service ARR': 'https://stats.metabase.com/public/question/4d6bf9dd-d3e3-43fb-ae80-9a1b7674068f.csv', 'Self Service Trials': 'https://stats.metabase.com/public/question/28855a12-c1b2-4616-ae8c-1f512e622ccb.csv'}


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


    def create_gsheet(self):
        """Generate Gsheet tabs based on URLs provided by Metabase """

        # I was trying ot put the sheet information in the credentials file

        # load spreadsheet information from credentials file
        # with open('.credentials.json') as f:
        #     credentials = json.load(f)
        #
        #     SPREADSHEET_ID = credentials['google_sheet_info']['SAMPLE_SPREADSHEET_ID']
        #     print(credentials)
        #     SPREADSHEET_RANGE = credentials['google_sheet_info']['SAMPLE_RANGE_NAME']
        #     print('sheet2', SPREADSHEET_RANGE)

        print('TODO: Ingest Metabase questions URLs')

        # Authenticate
        creds = None
        if os.path.exists('.token.json'):
            creds = Credentials.from_authorized_user_file('.token.json', SCOPES)
        # If there are no (valid) credentials available, let the user log in.
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file(
                    '.credentials.json', SCOPES)
                creds = flow.run_local_server(port=0)
            # Save the credentials for the next run
            with open('.token.json', 'w') as token:
                token.write(creds.to_json())

        # Push URL Values in the Master URL
        try:
            service = build('sheets', 'v4', credentials=creds)
            urls = {
                'values': []
            }

            # Loop through the JSON data
            for key, value in tabs_json.items():
                urls['values'].append([key, value])

            batch_update_body = {
                'valueInputOption': 'USER_ENTERED',
                'data': [{
                    'range': SAMPLE_RANGE_NAME,
                    'values': urls['values']
                }]
            }

            try:
                response = service.spreadsheets().values().batchUpdate(spreadsheetId=SAMPLE_SPREADSHEET_ID,
                                                                       body=batch_update_body).execute()
                print('Values updated successfully!')

            except HttpError as error:
                print(f'An error occurred: {error}')

        except HttpError as err:
            print(err)


