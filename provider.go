package main

import (
	"context"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func Provider() *schema.Provider {
	return &schema.Provider{
		DataSourcesMap: map[string]*schema.Resource{
			"pass_password": dataSourcePassword(),
		},
		ResourcesMap: map[string]*schema.Resource{
			"pass_password": resourcePassword(),
		},
		Schema: map[string]*schema.Schema{
			"store": {
				Description: "The absolute path of the password store to use, if not the default",
				Type:        schema.TypeString,
				Optional:    true,
			},
		},
		ConfigureContextFunc: providerConfigure,
	}
}

type ProviderConfiguration struct {
	store string
}

func providerConfigure(ctx context.Context, d *schema.ResourceData) (interface{}, diag.Diagnostics) {
	var diags diag.Diagnostics

	return ProviderConfiguration{
		store: d.Get("store").(string),
	}, diags
}
