# terraform-provider-pass

A Terraform provider to source credentials from your [pass](https://passwordstore.org/) store.

Not intended for wider consumption, hence not published to the Terraform registry.

Please note that **passwords will end up in your statefile as plaintext**, because they are loaded as data sources. Only use this plugin if you are comfortable accepting this risk. Otherwise consider alternatives, like handling your credentials as variables.

```tf
terraform {
  required_providers {
    pass = {
        source = "nicholas.cloud/nchlswhttkr/pass"
        version = ">= 0.2"
    }
  }
}

provider "pass" {
  store = "/path/to/.password-store"
}

data "pass_password" "hello_world" {
  name = "hello-world"
}

resource "local_file" "hello_world" {
    content  = data.pass_password.hello_world.password
    filename = "hello.txt"
}
```
