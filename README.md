# terraform-provider-pass

A Terraform provider to source credentials from your [pass](https://passwordstore.org/) store.

```tf
terraform {
  required_providers {
    pass = {
        source = "nicholas.cloud/nchlswhttkr/pass"
        version = ">= 0.1"
    }
  }
}

provider "pass" {}

data "pass_password" "hello_world" {
  name = "hello-world"
}

resource "local_file" "hello_world" {
    content  = data.pass_password.hello_world.password
    filename = "hello.txt"
}
```
