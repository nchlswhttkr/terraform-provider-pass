# terraform-provider-pass [![Build status](https://badge.buildkite.com/4928db4d42a60881751adb4baa3da1c04ec0bc133eeb7b40b0.svg)](https://buildkite.com/nchlswhttkr/terraform-provider-pass)

A Terraform provider to source credentials from your [pass](https://passwordstore.org/) store.

> [!WARNING]
> Please note that **passwords will end up in your statefile as plaintext**. Only use this provider if you are comfortable accepting this risk. Otherwise consider alternatives, like handling your credentials as variables.

This provider is not intended for wider consumption, hence why it isn't published to the Terraform registry.

The provider can be installed from my own registry.

```tf
# Install and configure the provider
terraform {
  required_providers {
    pass = {
        source = "nicholas.cloud/nchlswhttkr/pass"
        version = "<~ 0.4"
    }
  }
}

provider "pass" {
  # Defaults to $PASSWORD_STORE_DIR, if set in environment
  store = "/path/to/.password-store"
}
```

You can read passwords from the `pass_password` data source.

```tf
# Read credentials from your password store
data "pass_password" "read" {
  name = "read"
}

resource "local_sensitive_file" "hello_world" {
  content  = data.pass_password.read.password
  filename = "hello.txt"
}
```

Passwords can also be created with a `pass_password` resource.

```tf
# Store credentials from other sources to your password store
resource "pass_password" "write" {
  name     = "write"
  password = "hunter2"
}
```
