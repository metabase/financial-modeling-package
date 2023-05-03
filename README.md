# data-products

A library of data products that can be created from a single command.

Currently, financial model is the only data product. More will be added later if there is interest.

## Runtime Dependencies

The following sections will help you set up everything locally so that you can run a script to create your data
products.

Before you spent too much time doing that, note the data product has the following dependencies:

1. Metabase instance accessible from the Internet. We use public sharing on metric questions to export CSV data to
   Google Sheets, which require the URL to be accessible from the Internet.
2. Model or query cache turned on in the Metabase instance. Metrics query/question can take about 100+ seconds to
   finish, and unfortunately Google Sheets will timeout during import.
3. Stripe data ingested using [Fivetran](https://fivetran.com/docs/applications/stripe)
4. Stripe data stored in Postgres. All our SQLs are written for Postgres and likely won't work for other databases.
   Redshift might work as they are fairly similar, but not tested.
5. Access to Google Sheets. The financial model template is created in Google Sheets where you need to make a copy.

If you do not meet the dependencies, this won't work for you.

## Install Python 3

The data products are created using a Python script, so you must have Python installed before you can run it.

We tested our scripts using Python 3.10, so the equivalent or higher is recommended, however older 3.x versions will
probably work too.

On macOS, run the following to install:

```
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

```
gh repo clone metabase/data-products
```

## Setup env & run tests

We use `tox` to create Python environments and run tests. This is required to run the script in next step even if you
can't care about running tests.

On macOS, install it by running:

```console
brew install tox
```

For other platforms, follow these [installation instructions](https://tox.wiki/en/latest/installation.html).

Then go to local checkout directory for this repo and run `tox` to setup Python env and run tests:

```console
cd data-products
tox
```

## Setup data products

After running `tox`, a Python virtual environment is created that contains the `dap` script to setup/create data
products. dap is short for **da**ta **p**roducts.

Next, activate the environment using `source`, run `dap`, and answer a few questions to create a config file for your
setup:

```
source .tox/data-products/bin/activate
dap setup
```

It will ask you about your Metabase instance, Stripe schema, and the collection where you want to create Metabase
models/questions. Note that your instance must be accessible from the Internet as we will create a publicly shared
question with metrics that will be imported into a Google Sheets template later.

The config file is written to `config.yml` where it contains all the informations that you provided along with a mapping
of your Stripe products. Do edit the file and make sure the product names are what you want to see in your financial
model and indicate which is a main product or not. A main product is a product that you want to roll your Stripe
subscription items into while other products will be collapsed into the former.

## Create data products

Using the config file, magic happens and data products are created by running `dap`:

```
dap create
```

It will create the requested Metabase collection from previous step, a few models/questions, turn on public sharing for
the metric questions and provide URLs to the CSV export.

Next, make a copy of the Google Sheets financial model template at <TODO: Add url to read-only template> and plug in
the CSV URLs into the Inputs tab. If the import is successful, you would have a working financial model with historical
data in the Summary tab and forecasts in the Forecasted Summary tab now! Congrats!!

Lastly, learn more about how to use the spreadsheet in the Info tab.

**NOTE**: The import may time out. You can check the "\_import" prefixed tabs for progress and result. Make sure that
your Metabase instance has model or query cache turned on, otherwise the CSV export would take too long (over 100
seconds) and won't ever work. Wait a few minutes for the cache to kick in, and then try again by deleting the URL in the
spreadsheet and reverting.
