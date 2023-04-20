# import requests
# import io
# from openpyxl import Workbook
# from openpyxl.utils.dataframe import dataframe_to_rows
#
# # Define the URL of the CSV file
# csv_url = '<snip>'
#
# # Fetch the CSV data from the URL
# response = requests.get(csv_url)
# csv_data = response.content.decode('utf-8')
#
# # Load the CSV data into a new workbook in memory
# wb = Workbook()
# ws = wb.active
# rows = csv_data.split('\n')
# for r in rows:
#     ws.append(r.split(','))
#
# # Pivot the table
# ws_pivot = wb.create_sheet('Pivoted Table')
# ws_pivot['A1'] = 'Plan Name'
# month_cols = ws.iter_cols(min_row=1, max_row=1, min_col=3)
# for col in month_cols:
#     ws_pivot.cell(row=1, column=col[0].column).value = col[0].value
# plan_names = ws.iter_cols(min_row=2, max_row=ws.max_row, min_col=1, max_col=1)
# for name in plan_names:
#     plan_row = ws_pivot.max_row + 1
#     ws_pivot.cell(row=plan_row, column=1).value = name[0].value
#     for col in month_cols:
#         month = col[0].value
#         monthly_revenue = ws.cell(row=name[0].row, column=col[0].column).value
#         ws_pivot.cell(row=plan_row, column=col[0].column).value = monthly_revenue
#
# wb.save('pivoted_table.xlsx')
# # Save the Excel workbook


# TEST 2


import requests
from openpyxl import Workbook

# Define the URL of the CSV file
csv_url = '<snip>'

# Fetch the CSV data from the URL
response = requests.get(csv_url)
csv_data = response.content.decode('utf-8')

# Load the CSV data into a new workbook in memory
wb = Workbook()
ws = wb.active
rows = csv_data.split('\n')
for r in rows:
    ws.append(r.split(','))

# Pivot the table using the Excel API
ws_pivot = wb.create_sheet('Pivoted Table')

# Set up the header row
ws_pivot['A1'] = 'Plan Name'
month_cols = ws.iter_cols(min_row=1, max_row=ws.max_row, min_col=3)
for col in month_cols:
    ws_pivot.cell(row=1, column=col[0].column).value = col[0].value
    print('col[0].value', col[0].value)

print('month_cols:', month_cols)
# Loop over the plan names and fill in the pivoted table
plan_names = ws.iter_cols(min_row=2, max_row=ws.max_row, min_col=1, max_col=1)
for name in plan_names:
    plan_row = ws_pivot.max_row + 1
    ws_pivot.cell(row=plan_row, column=1).value = name[0].value

    print('plan_row:', plan_row)
    print('name[0].value:', name[0].value)
    # print('name:', name)

    # Loop over the months and fill in the monthly revenue values
    for col in month_cols:
        month = col[0].value
        monthly_revenue = ws.cell(row=name[0].row, column=col[0].column).value
        month_column_index = col[0].column

        print('month:', month)
        print('monthly_revenue', monthly_revenue)

        # If the column for the month doesn't exist yet, add it
        if not ws_pivot.cell(row=1, column=month_column_index).value:
            ws_pivot.cell(row=1, column=month_column_index).value = month
            print('in loop if does not exist yet')
        # Fill in the monthly revenue value for the corresponding plan and month
        ws_pivot.cell(row=plan_row, column=month_column_index).value = monthly_revenue

# Save the Excel workbook
wb.save('pivoted_table.xlsx')

print('TODO: force new update')
