package main

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func dataSourcePassword() *schema.Resource {
	return &schema.Resource{
		Description: "A password stored within your password vault",
		ReadContext: dataSourcePasswordRead,
		Schema: map[string]*schema.Schema{
			"password": {
				Description: "The decrypted password's value",
				Type:        schema.TypeString,
				Computed:    true,
				Sensitive:   true,
			},
			"name": {
				Description: "The name of the password to decrypt",
				Type:        schema.TypeString,
				Required:    true,
			},
		},
	}
}

func dataSourcePasswordRead(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
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
	err := cmd.Run()
	if err != nil {
		for _, line := range strings.Split(stderr.String(), "\n") {
			log.Printf("[ERROR] %s\n", line)
		}
		return diag.FromErr(err)
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
