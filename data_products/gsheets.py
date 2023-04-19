from __future__ import print_function

import os.path
import json

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# If modifying these scopes, delete the file token.json.
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']


def create_gsheets():

    print('TODO: Read Metabase questions URLs from config.yml')
    print('TODO: Create GSheet Tabs Dynamically & Import Data')

    # load spreadsheet information from credentials file
    with open('.credentials.json') as f:
        credentials = json.load(f)

        SAMPLE_SPREADSHEET_ID = credentials['google_sheet_info']['SAMPLE_SPREADSHEET_ID']
        SAMPLE_RANGE_NAME = credentials['google_sheet_info']['SAMPLE_RANGE_NAME']
        tabs_json = credentials['tabs_json']

    print("Updating spreadsheet_ID", credentials['google_sheet_info']['SAMPLE_SPREADSHEET_ID'])
    # print('\tIn range', credentials['google_sheet_info']['SAMPLE_RANGE_NAME'])

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
            service.spreadsheets().values().batchUpdate(spreadsheetId=SAMPLE_SPREADSHEET_ID,
                                                        body=batch_update_body).execute()
            print('URL values updated successfully!')

        except HttpError as error:
            print(f'An error occurred: {error}')

    except HttpError as err:
        print(err)

    # I know how to generate the tab if it does not exist but IMPORTDATA is not working as expected

    # for key in tabs_json:
    #     sheets = service.spreadsheets().get(spreadsheetId=SAMPLE_SPREADSHEET_ID).execute().get('sheets', [])
    #     sheet_exists = any(sheet['properties']['title'] == key for sheet in sheets)
    #
    #     #if the tab does not exist then generate it
    #     if sheet_exists == False:
    #         requests = [
    #             {
    #                 'addSheet': {
    #                     'properties': {
    #                         'title': key,
    #                     },
    #                 },
    #             },
    #             {
    #                 'setDataValidation': {
    #                     'rule': {
    #                         'condition': {
    #                             'type': 'CUSTOM_FORMULA',
    #                             'values': [
    #                                 {
    #                                     'userEnteredValue': f'=IMPORTDATA("{tabs_json[key]}")',
    #                                 },
    #                             ],
    #                         },
    #                         'inputMessage': 'Imported Data',
    #                     },
    #                 },
    #             },
    #         ]
    #
    #         # Send the batch update request to create the new sheet
    #         try:
    #             response = service.spreadsheets().batchUpdate(
    #                 spreadsheetId=SAMPLE_SPREADSHEET_ID,
    #                 body={'requests': requests}
    #             ).execute()
    #             print(f"Sheet '{key}' with IMPORTDATA URL '{tabs_json[key]}' has been created.")
    #         except HttpError as error:
    #             print(f"An error occurred: {error}")
    #
    #     #
    #     if sheet_exists:
    #         print('TODO: check to see if the URL has changed to update the sheet')


if __name__ == '__main__':
    create_gsheets()
