# data-products
A library of data products that can be created from a single command.

## Setup env & run tests

If you don't already have `tox`, install it to manage Python env and testing:

```console
brew install tox
```

Go to local checkout directory for this repo and run `tox` to setup Python env and run tests.
```console
tox
```

## Setup data products using `dap`

Answer a few prompts to create a config file.

```
source .tox/data-products/bin/activate
dap setup
```

## Create data products using `dap`

Using the config file, magic happens and data products are created.
```
dap create
```
