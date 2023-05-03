# data-products
A library of data products that can be created from a single command.

Currently, financial model is the only data product. More will be added later if there is interest.

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

Then go to local checkout directory for this repo and run `tox` to setup Python env and run tests:

```console
cd data-products
tox
```

## Setup data products

After running `tox`, a Python virtual environment is created that contains the `dap` script to setup/create data
products.

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

NOTE: The import may time out. You can check the "\_import" prefixed tabs for progress and result. Make sure that
your Metabase instance has model or query cache turned on, otherwise the CSV export would take too long (over 100
seconds) and won't ever work. Wait a few minutes for the cache to kick in, and then try again by deleting the URL in the
spreadsheet and reverting.
