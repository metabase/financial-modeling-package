# data-products

A library of data products that can be created from a single command.

Currently, financial model is the only data product. More will be added later if there is interest.

## Requirements

In order to use this to create data products, the following requirements must be met. If you do not meet all the
requirements, this won't work for you.

1. Admin username/password for a Metabase instance. The script uses it to create models/questions via API.
2. Metabase instance accessible from the internet. We use public sharing on metric questions to export CSV data to
   Google Sheets, which requires the URL to be accessible from the internet.
3. Model or query caching turned on in the Metabase instance. Metrics query/question can take about 100+ seconds to
   finish, and unfortunately Google Sheets will timeout during import without caching.
   [Model caching](https://www.metabase.com/docs/latest/data-modeling/models#model-caching) is preferred for
   best experience, but [query caching](https://www.metabase.com/docs/latest/configuring-metabase/caching) is sufficient.
4. Stripe data ingested using [Fivetran](https://fivetran.com/docs/applications/stripe)
5. Stripe data stored in Postgres. All our SQLs are written for Postgres and likely won't work for other databases.
   Redshift might work as they are fairly similar, but not tested.
6. Access to Google Sheets. The financial model template is created in Google Sheets where you need to make a copy.

## Install Python 3

The data products are created using a Python script, so you must have Python installed before you can run it.

We tested the script using Python 3.10, so the equivalent or higher is recommended, however older 3.x versions will
probably work too.

On macOS, run the following to install:

```console
brew install python3
```

For other platforms, see [download page on python.com](https://www.python.org/downloads/)


## Checkout repo

In order to create the data products, you must checkout this repo using `gh` CLI.
Install it by following the [instructions on github.com](https://cli.github.com/).
For macOS, you can simply run the following command:

```console
brew install gh
```

Once installed, run the following command to checkout this repo:

```console
gh repo clone metabase/data-products
```

## Set up environments & run tests

We use `tox` to create Python environments and run tests. This is required to run the script in the next step even if you
can't care about running tests.

On macOS, install it by running:

```console
brew install tox
```

For other platforms, follow these [installation instructions](https://tox.wiki/en/latest/installation.html).

Then go to local checkout directory for this repo and run `tox` to set up Python environments and run tests:

```console
cd data-products
tox
```

## Set up data products

After running `tox`, a Python virtual environment is created that contains the `dap` script to set up/create data
products. dap is short for **da**ta **p**roducts.

Next, activate the environment using `source`, run `dap`, and answer a few questions to create a config file for your
setup:

```console
source .tox/data-products/bin/activate
dap setup
```

It will ask you about your Metabase instance, Stripe schema, and the collection where you want to create Metabase
models/questions. Note that your instance must be accessible from the internet as we will create publicly shared
questions with metrics that will be imported into a Google Sheets template later.

The config file is written to `config.yml` where it contains all the informations that you provided along with a mapping
of your Stripe products. Do edit the file and make sure the product names are what you want to see in your financial
model and indicate which is a main product. A main product is a product that you want to roll your Stripe
subscription items into while other products will be collapsed into the former.

## Create data products

Using the config file, magic happens and data products are created by running:

```console
dap create
```

It will create the requested Metabase collection from previous step, a few models/questions, turn on public sharing for
the metric questions, and provide URLs to the CSV exports.

Next, make a copy of the Google Sheets financial model template at <TODO: Add url to read-only template> and plug in
the CSV URLs into the Inputs tab. If the import is successful, you would have a working financial model with historical
data in the Summary tab and forecasts in the Forecasted Summary tab now! Congrats!!

Lastly, learn more about how to use the spreadsheet in the Info tab.

**NOTE**: The import may time out. You can check the "\_import" prefixed tabs for progress and result. Make sure that
your Metabase instance has model or query cache turned on, otherwise the CSV export would take too long (over 100
seconds) and won't ever work. Wait a few minutes for the cache to kick in, and then try again by deleting the URL in the
spreadsheet and reverting. You can open the exported metrics questions in Metabase to ensure they load within 30 secs
before trying the import.
