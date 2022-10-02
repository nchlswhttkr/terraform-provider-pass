package main

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func resourcePassword() *schema.Resource {
	return &schema.Resource{
		Description:   "A password stored within your password vault.",
		CreateContext: resourcePasswordUpdate,
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
			},
		},
	}
}

func resourcePasswordRead(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	var diags diag.Diagnostics

	name := d.Get("name").(string)
	store := m.(ProviderConfiguration).store

	cmd := exec.Command("pass", "show", name)
	if store != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("PASSWORD_STORE_DIR=%s", store))
	}
	tty, set := os.LookupEnv("GPG_TTY")
	if set {
		cmd.Env = append(cmd.Env, fmt.Sprintf("GPG_TTY=%s", tty))
	}
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		diags = diag.FromErr(err)
		diags[0].Detail = stderr.String()
		return diags
	}

	password := stdout.String()
	// Strip trailing newline from one-line passwords
	if strings.Count(password, "\n") == 1 {
		password = strings.TrimSuffix(stdout.String(), "\n")
	}
	if err := d.Set("password", password); err != nil {
		return diag.FromErr(err)
	}
	d.SetId(name)

	return diags
}

func resourcePasswordUpdate(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	var diags diag.Diagnostics

	name := d.Get("name").(string)
	password := d.Get("password").(string)
	store := m.(ProviderConfiguration).store

	cmd := exec.Command("pass", "insert", "--force", name)
	if store != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("PASSWORD_STORE_DIR=%s", store))
	}
	tty, set := os.LookupEnv("GPG_TTY")
	if set {
		cmd.Env = append(cmd.Env, fmt.Sprintf("GPG_TTY=%s", tty))
	}
	var stdin bytes.Buffer = *bytes.NewBufferString(fmt.Sprintf("%s\n%s\n", password, password))
	cmd.Stdin = &stdin
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		diags = diag.FromErr(err)
		diags[0].Detail = stderr.String()
		return diags
	}

	d.SetId(name)

	return diags
}

func resourcePasswordDelete(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	var diags diag.Diagnostics

	name := d.Get("name").(string)
	store := m.(ProviderConfiguration).store

	cmd := exec.Command("pass", "rm", "--force", name)
	if store != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("PASSWORD_STORE_DIR=%s", store))
	}
	tty, set := os.LookupEnv("GPG_TTY")
	if set {
		cmd.Env = append(cmd.Env, fmt.Sprintf("GPG_TTY=%s", tty))
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		diags = diag.FromErr(err)
		diags[0].Detail = stderr.String()
		return diags
	}

	d.SetId(name)

	return diags
}
