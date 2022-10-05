package main

import (
	"context"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func resourcePassword() *schema.Resource {
	return &schema.Resource{
		Description:   "A password stored within your password vault.",
		CreateContext: resourcePasswordCreate,
		ReadContext:   resourcePasswordRead,
		UpdateContext: resourcePasswordUpdate,
		DeleteContext: resourcePasswordDelete,
		SchemaVersion: 1,
		Schema: map[string]*schema.Schema{
			"password": {
				Description: "The decrypted password's value.",
				Type:        schema.TypeString,
				Required:    true,
				Sensitive:   true,
			},
			"name": {
				Description: "The name of the password to decrypt.",
				Type:        schema.TypeString,
				Required:    true,
				ForceNew:    true,
			},
		},
	}
}

func resourcePasswordCreate(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	name := d.Get("name").(string)
	password := d.Get("password").(string)
	store := m.(ProviderConfiguration).store

	client := NewPassClient(store)
	diags := client.CreatePassword(name, password)

	if !diags.HasError() {
		d.SetId(name)
	}
	return diags
}

func resourcePasswordRead(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
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

func resourcePasswordUpdate(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	name := d.Get("name").(string)
	password := d.Get("password").(string)
	store := m.(ProviderConfiguration).store

	client := NewPassClient(store)
	diags := client.OverwritePassword(name, password)

	if !diags.HasError() {
		d.SetId(name)
	}
	return diags
}

func resourcePasswordDelete(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	name := d.Get("name").(string)
	store := m.(ProviderConfiguration).store

	client := NewPassClient(store)
	if diags := client.DeletePassword(name); diags.HasError() {
		return diags
	}

	d.SetId("")
	return nil
}
