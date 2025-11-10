# AWS SSO Account Switcher

A bash/zsh script that simplifies switching between multiple AWS SSO accounts and automatically switches Kubernetes contexts.

## Features

- 🔄 **Easy Account Switching**: Interactive menu to select AWS accounts
- 🔐 **SSO Integration**: Handles AWS SSO login automatically
- ☸️ **Kubernetes Context**: Automatically switches kubectl context
- 🛡️ **Security First**: Account IDs stored in separate config file
- 🎯 **Shell Compatible**: Works in both bash and zsh
- 📝 **Validation**: Verifies access and provides clear feedback

## Prerequisites

### Required

- `aws` CLI v2 with SSO configured
- `jq` for JSON parsing

### Optional

- `kubectl` for Kubernetes context switching
- `kubectx` for enhanced context switching (falls back to kubectl)

### Installation Commands

```bash
# macOS (using Homebrew)
brew install awscli jq kubectl kubectx

# Ubuntu/Debian
sudo apt update
sudo apt install awscli jq kubectl
```

## Setup

### 1. Clone or Download

```bash
git clone git@github.com:geek-kb/DevopsStuff.git
cd Scripts/aws_sso_accounts_switcher
```

### 2. Configure Your Accounts

```bash
# Copy the template
cp aws_accounts.conf.template aws_accounts.conf

# Edit with your account details
vim aws_accounts.conf
```

#### Custom Configuration File Location

By default, the script looks for `aws_accounts.conf` in the same directory as the script. You can customize this by modifying the `AWS_ACCOUNTS_CONF_FILE` variable at the beginning of the script:

```bash
# Edit the script to point to a different config file location
vim aws_sso_switcher.sh

# Example configurations:
# For a different filename in the same directory:
AWS_ACCOUNTS_CONF_FILE="my_aws_accounts.conf"

# For an absolute path:
AWS_ACCOUNTS_CONF_FILE="/home/user/.config/aws_accounts.conf"

# For a relative path:
AWS_ACCOUNTS_CONF_FILE="../configs/aws_accounts.conf"
```

Alternatively, you can set the path via environment variable:

```bash
# Set via environment variable (overrides script default)
export AWS_ACCOUNTS_CONF_FILE="/path/to/your/config.conf"
source ./aws_sso_switcher.sh
```

### 3. Account Configuration Format

Edit `aws_accounts.conf` with your AWS accounts:

```bash
# Format: "label|profile|account_id|k8s_context"
Development Account (123456789012)|dev-profile|123456789012|dev-k8s-context
Production Account (987654321098)|prod-profile|987654321098|prod-k8s-context
Staging Account (555666777888)|staging-profile|555666777888|
Management Account (444555666777)|mgmt-profile|444555666777|mgmt-k8s-context
```

**Field Descriptions:**

- **label**: Human-readable name shown in the menu
- **profile**: AWS CLI profile name (must match `~/.aws/config`)
- **account_id**: 12-digit AWS account ID
- **k8s_context**: Kubernetes context name (leave empty if not applicable)

### 4. AWS CLI Configuration

Ensure your `~/.aws/config` has SSO profiles configured:

```ini
[profile dev-profile]
sso_start_url = https://your-company.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = DeveloperAccess
region = us-east-1

[profile prod-profile]
sso_start_url = https://your-company.awsapps.com/start
sso_region = us-east-1
sso_account_id = 987654321098
sso_role_name = ReadOnlyAccess
region = us-east-1
```

## Usage

### Method 1: Source the script (Recommended)

```bash
# Source the script to run it
source ./aws_sso_switcher.sh

# Or make it available globally by adding to your shell profile:
echo 'alias sso="source /path/to/aws_sso_switcher.sh"' >> ~/.zshrc
```

### Method 2: Create a wrapper function

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
sso() {
  local script="/path/to/aws_sso_switcher.sh"
  if [[ ! -f "$script" ]]; then
    echo "Error: Script not found at $script"
    return 1
  fi

  source "$script"
}
```

### Interactive Menu

When you run the script, you'll see:

```
Please select the AWS account you'd like to access:

1) Development Account (123456789012)
2) Production Account (987654321098)
3) Staging Account (555666777888)
4) Management Account (444555666777)

#?
```

## Output Example

```
Selected account: Development Account (123456789012)

Not logged in or session expired. Initiating SSO login...
# SSO browser login flow...

✅ Successfully configured AWS access!
Account ID: 123456789012
User ARN:   arn:aws:sts::123456789012:assumed-role/DeveloperAccess/username
Profile:    dev-profile

AWS_PROFILE is set to: dev-profile

Switching Kubernetes context to 'dev-k8s-context'...
✅ Switched to Kubernetes context: dev-k8s-context

You can now use AWS CLI and kubectl commands.
To use this in other terminals:
  export AWS_PROFILE="dev-profile"
```

## Security

- ✅ Account IDs are stored in a separate config file
- ✅ Config file is excluded from git via `.gitignore`
- ✅ Template file can be safely shared publicly
- ✅ Script handles potential alias conflicts

## Troubleshooting

### Error: "Script not found"

- Ensure the script path is correct
- Use absolute paths when creating aliases/functions

### Error: "Configuration file required"

- Copy `aws_accounts.conf.template` to `aws_accounts.conf`
- Add your account configurations
- If using a custom config file path, ensure the `AWS_ACCOUNTS_CONF_FILE` variable points to the correct location
- Verify the config file exists and has proper read permissions

### Error: "SSO login failed"

- Check your AWS CLI configuration
- Verify SSO start URL is correct
- Try running `aws sso login --profile <profile-name>` manually

### Error: "kubectl context switch failed"

- Verify the Kubernetes context name exists: `kubectl config get-contexts`
- Install kubectl if missing: `brew install kubectl`

### Error: "Required command not found"

- Install missing dependencies (aws, jq, kubectl)
- Ensure they're in your PATH

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with multiple accounts
5. Submit a pull request

## License

MIT License - feel free to use and modify as needed.

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review AWS CLI and SSO documentation
3. Open an issue in the repository

