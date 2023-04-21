from __future__ import print_function

import datetime
import os.path
import json

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# If modifying these scopes, delete the file token.json.
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

# load spreadsheet information from credentials file
with open('.credentials.json') as f:

    credentials = json.load(f)
    SAMPLE_SPREADSHEET_ID = credentials['google_sheet_info']['SAMPLE_SPREADSHEET_ID']
    SAMPLE_RANGE_NAME = credentials['google_sheet_info']['SAMPLE_RANGE_NAME']
    tabs_json = credentials['tabs_json']


def create_gsheets():

    print('TODO: Read Metabase questions URLs from config.yml')
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

    # Generate the tabs if they don't exist and update them if they do

    print('TODO: Create GSheet Tabs Dynamically & Import Data')
    for key, value in tabs_json.items():
        # the key here is the name of the Metabase Question and the value is the URL of the question

        sheets = service.spreadsheets().get(spreadsheetId=SAMPLE_SPREADSHEET_ID).execute().get('sheets', [])
        sheet_exists = any(sheet['properties']['title'] == key for sheet in sheets)

        # if the tab does not exist then generate it
        if sheet_exists is False:

            # Create a new sheet in the spreadsheet & set the title
            sheet_body = {
                'requests': [
                    {
                        'addSheet': {
                            'properties': {
                                'title': key,
                            }
                        }
                    }
                ]
            }
            response = service.spreadsheets().batchUpdate(spreadsheetId=SAMPLE_SPREADSHEET_ID,
                                                          body=sheet_body).execute()

            # Get the sheet ID of the new sheet
            sheet_id = response['replies'][0]['addSheet']['properties']['sheetId']

            # Set the formula in the custom field of the new sheet
            formula = f'=IMPORTDATA("{value}")'
            cell_data = {
                'userEnteredValue': {
                    'formulaValue': formula
                },
                'userEnteredFormat': {
                    'numberFormat': {
                        # 'type': 'NUMBER'
                        'type': 'DATE',
                        'pattern': 'yyyy-mm-dd'
                    }
                }
            }

            cell_range = {
                'sheetId': sheet_id,
                'startRowIndex': 0,
                'startColumnIndex': 0,
                'endRowIndex': 1,
                'endColumnIndex': 1
            }
            repeat_cell_request = {
                'repeatCell': {
                    'range': cell_range,
                    'cell': cell_data,
                    'fields': 'userEnteredValue,userEnteredFormat'
                }
            }
            body = {
                'requests': [repeat_cell_request]
            }
            response = service.spreadsheets().batchUpdate(spreadsheetId=SAMPLE_SPREADSHEET_ID, body=body).execute()

            # DATE FORMATTING

            # Get the sheet ID of the new sheet
            # Get the data range of the first row
            data_range = f"{key}!1:1"
            request = service.spreadsheets().values().batchGet(spreadsheetId=SAMPLE_SPREADSHEET_ID, ranges=[data_range],
                                                               valueRenderOption='UNFORMATTED_VALUE')
            response = request.execute()
            values = response['valueRanges'][0]['values'][0]

            # Format the first row if the cells are dates
            cell_updates = []
            for i, cell_value in enumerate(values):
                cell_range = {
                    'sheetId': sheet_id,
                    'startRowIndex': 0,
                    'startColumnIndex': i,
                    'endRowIndex': 1,
                    'endColumnIndex': i + 1
                }

                if '/' in str(cell_value):
                    date_obj = datetime.datetime.strptime(str(cell_value), '%m/%d/%Y').date()
                    formatted_date = date_obj.strftime('%Y-%m-%d')
                    cell_updates.append({
                        'repeatCell': {
                            'range': cell_range,
                            'cell': {
                                'userEnteredValue': {
                                    'stringValue': formatted_date
                                },
                                'userEnteredFormat': {
                                    'numberFormat': {
                                        'type': 'DATE',
                                        'pattern': 'yyyy-mm-dd'
                                    }
                                }
                            },
                            'fields': 'userEnteredValue.stringValue,userEnteredFormat.numberFormat'
                        }
                    })

            # Apply cell formatting changes, if any
            if cell_updates:
                body = {
                    'requests': cell_updates
                }
                response = service.spreadsheets().batchUpdate(spreadsheetId=SAMPLE_SPREADSHEET_ID, body=body).execute()

        if sheet_exists:
            print('TODO: check to see if the URL has changed to update the sheet')
            print('SHEET EXISTS ALREADY')


if __name__ == '__main__':
    create_gsheets()
