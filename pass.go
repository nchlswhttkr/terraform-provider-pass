package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
)

type PassClient struct {
	store string
	tty   string
}

func NewPassClient(store string) PassClient {
	tty := os.Getenv("GPG_TTY")
	return PassClient{
		store,
		tty,
	}
}

func (p PassClient) CreatePassword(name string, password string) diag.Diagnostics {
	multiline := strings.Contains(password, "\n")

	var cmd exec.Cmd
	if multiline {
		cmd = *exec.Command("pass", "insert", "--multiline", name)
		cmd.Stdin = bytes.NewBufferString(password)
	} else {
		cmd = *exec.Command("pass", "insert", name)
		cmd.Stdin = bytes.NewBufferString(fmt.Sprintf("%s\n%s\n", password, password))
	}
	if p.store != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("PASSWORD_STORE_DIR=%s", p.store))
	}
	if p.tty != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("GPG_TTY=%s", p.tty))
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		diags := diag.FromErr(err)
		diags[0].Detail = stderr.String()
		return diags
	}
	return nil
}

func (p PassClient) OverwritePassword(name string, password string) diag.Diagnostics {
	multiline := strings.Contains(password, "\n")

	var cmd exec.Cmd
	if multiline {
		cmd = *exec.Command("pass", "insert", "--force", "--multiline", name)
		cmd.Stdin = bytes.NewBufferString(password)
	} else {
		cmd = *exec.Command("pass", "insert", "--force", name)
		cmd.Stdin = bytes.NewBufferString(fmt.Sprintf("%s\n%s\n", password, password))
	}
	if p.store != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("PASSWORD_STORE_DIR=%s", p.store))
	}
	if p.tty != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("GPG_TTY=%s", p.tty))
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		diags := diag.FromErr(err)
		diags[0].Detail = stderr.String()
		return diags
	}
	return nil
}

func (p PassClient) DeletePassword(name string) diag.Diagnostics {
	cmd := exec.Command("pass", "rm", "--force", name)
	if p.store != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("PASSWORD_STORE_DIR=%s", p.store))
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		diags := diag.FromErr(err)
		diags[0].Detail = stderr.String()
		return diags
	}
	return nil
}

func (p PassClient) GetPassword(name string) (string, diag.Diagnostics) {
	cmd := exec.Command("pass", "show", name)
	if p.store != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("PASSWORD_STORE_DIR=%s", p.store))
	}
	if p.tty != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("GPG_TTY=%s", p.tty))
	}
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		diags := diag.FromErr(err)
		diags[0].Detail = stderr.String()
		return "", diags
	}

	password := stdout.String()
	// Strip trailing newline from one-line passwords, leave multiline untouched
	if strings.Count(password, "\n") == 1 {
		password = strings.TrimSuffix(stdout.String(), "\n")
	}
	return password, nil
}
