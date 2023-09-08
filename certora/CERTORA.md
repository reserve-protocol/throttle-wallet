## Running the prover

The cleanest way to run these specifications is to create a Python virtual environment and install all dependencies there.

```
mkdir certora_venv
python -m venv certora_venv
cd certora_venv
source bin/activate
```

Note that Python 3.8.16 or higher is required to run the latest version of the Certora command line tool. Certora dependencies and installation are described here:
https://docs.certora.com/en/latest/docs/user-guide/getting-started/install.html

The `CERTORAKEY` environment variable must be set to a valid Certora key. The "pay-as-you-go" trial is currently completely free.

The Makefile added to the root of the repository can be used to run either all rules (`make certora`) or a specific rule (`make certora rule=my_rule`).

## Caveats

* To ensure production bytecode is checked, the `solc` configuration in the Makefile must _exactly_ match that in foundry.toml (or whatever the source of truth is).
* For simplicity a copy of the `solc` version 0.8.21 binary was included in this directory, however, ideally the same binary is used for proving as is used for testing and deployment.
* Some rules depend on the storage layout slightly--if this changes, they will need to be updated to keep working. 
