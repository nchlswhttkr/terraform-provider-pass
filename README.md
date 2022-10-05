# terraform-provider-pass

A Terraform provider to source credentials from your [pass](https://passwordstore.org/) store.

Not intended for wider consumption, hence not published to the Terraform registry.

Please note that **passwords will end up in your statefile as plaintext**, because they are loaded as data sources. Only use this plugin if you are comfortable accepting this risk. Otherwise consider alternatives, like handling your credentials as variables.

```tf
# Install and configure the provider
terraform {
  required_providers {
    pass = {
        source = "nicholas.cloud/nchlswhttkr/pass"
        version = "<~ 0.1"
    }
  }
}

provider "pass" {
  store = "/path/to/.password-store"
}

# Read credentials from your password store
data "pass_password" "read_password" {
  name = "read-password"
}

resource "local_sensitive_file" "hello_world" {
  content  = data.pass_password.read_password.password
  filename = "hello.txt"
}

# Store credentials from other sources to your password store
resource "pass_password" "store_password" {
  name     = "write-password"
  password = "hunter2"
}
```
