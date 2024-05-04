package main

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
)

type PassClient struct {
	store string
}

func NewPassClient(store string) PassClient {
	return PassClient{
		store,
	}
}

func (p PassClient) CreatePassword(name string, password string) diag.Diagnostics {
	{
		// Since pass has no "exists" check, duplicate their passfile check
		// https://git.zx2c4.com/password-store/tree/src/password-store.sh?id=eea24967a002a2a81ae9b97a1fe972b5287f3a09#n454
		store := p.store
		if store == "" {
			if home, set := os.LookupEnv("HOME"); set {
				store = filepath.Join(home, ".password-store")
			} else {
				return diag.Errorf("Could not read HOME environment variable")
			}
		}
		passfile := filepath.Join(store, fmt.Sprintf("%s.gpg", name))
		if _, err := os.Stat(passfile); !errors.Is(err, os.ErrNotExist) {
			return diag.Errorf("Password \"%s\" already exists in password store (%s)", name, passfile)
		}
	}

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
		cmd.Env = append(os.Environ(), fmt.Sprintf("PASSWORD_STORE_DIR=%s", p.store))
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
		cmd.Env = append(os.Environ(), fmt.Sprintf("PASSWORD_STORE_DIR=%s", p.store))
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
		cmd.Env = append(os.Environ(), fmt.Sprintf("PASSWORD_STORE_DIR=%s", p.store))
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
		cmd.Env = append(os.Environ(), fmt.Sprintf("PASSWORD_STORE_DIR=%s", p.store))
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
