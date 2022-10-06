package main

import (
	"context"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func dataSourcePassword() *schema.Resource {
	return &schema.Resource{
		Description:   "Reads a password from your password store.",
		ReadContext:   dataSourcePasswordRead,
		SchemaVersion: 1,
		Schema: map[string]*schema.Schema{
			"password": {
				Description: "The decrypted password's value.",
				Type:        schema.TypeString,
				Computed:    true,
				Sensitive:   true,
			},
			"name": {
				Description: "The name of the password to decrypt.",
				Type:        schema.TypeString,
				Required:    true,
			},
		},
	}
}

func dataSourcePasswordRead(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	name := d.Get("name").(string)
	store := m.(ProviderConfiguration).store

	client := NewPassClient(store)
	password, diags := client.GetPassword(name)
	if diags.HasError() {
		return diags
	}

	if err := d.Set("password", password); err != nil {
		diags = append(diags, diag.FromErr(err)...)
		return diags
	}

	d.SetId(name)
	return diags
}
