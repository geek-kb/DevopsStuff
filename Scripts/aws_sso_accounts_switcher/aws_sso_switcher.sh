#!/bin/bash
# aws_sso_switcher.sh
# Works when *sourced* from zsh or bash. Also guards against global aliases like `alias -g sso=...`
# to prevent breaking `aws sso login`.

# -----------------------------
# SAFETY & SHELL COMPATIBILITY
# -----------------------------
# If your shell has a *global* alias named "sso", it will corrupt the command `aws sso login`.
# We neutralize it here.
if alias -g sso >/dev/null 2>&1; then
  unalias -g sso 2>/dev/null
fi

# Detect if this file is being sourced (so we can `return` instead of `exit` on errors)
__aws_sso_switcher__is_sourced() {
  # zsh - check this first since we're primarily using zsh
  if [ -n "${ZSH_EVAL_CONTEXT:-}" ]; then
    case "$ZSH_EVAL_CONTEXT" in
    *:file:*) return 0 ;;
    *:file) return 0 ;;
    esac
  fi

  # bash
  if [ -n "${BASH_SOURCE:-}" ]; then
    # In bash, compare BASH_SOURCE[0] with $0
    # When sourced: BASH_SOURCE[0] is the script path, $0 is the shell (e.g., bash)
    # When executed: BASH_SOURCE[0] equals $0
    if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
      return 0
    fi
  fi

  # POSIX fallback - check if $0 looks like a shell
  case "${0}" in
  *bash | *zsh | *sh | *ksh) return 0 ;;
  esac

  return 1
}

__aws_sso_switcher__die() {
  echo "ERROR: $*" 1>&2
  if __aws_sso_switcher__is_sourced; then
    # Clean up any partial state
    unset _accounts _choice _selected _label _rest _selected_profile _selected_account_id _k8s_context
    unset _sso_error _caller_json _account_id _user_arn _verify_error
    return 1
  else
    exit 1
  fi
}

# Enable error handling - but be careful with sourced scripts
# Don't use 'set -e' as it will exit the shell when sourced
# Instead, we handle errors explicitly

# On some minimal environments TERM might not be set; helps some CLIs format output
export TERM="${TERM:-xterm-256color}"

# ---------------
# REQUIREMENTS
# ---------------
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || __aws_sso_switcher__die "Required command '$1' not found in PATH"
}

need_cmd aws
need_cmd jq
# kubectl is optional but recommended if you want to switch contexts
command -v kubectl >/dev/null 2>&1 || echo "Note: 'kubectl' not found; Kubernetes context switch may be skipped"
# kubectx is optional; we can fall back to kubectl
# jq is mandatory for parsing sts output

# --------------------
# ACCOUNT SELECTION UI
# --------------------

# Load account mappings from config file
_config_file="$HOME/.dotfiles/zsh/zsh.d/personal/aws_accounts.conf"
_template_file="$HOME/.dotfiles/zsh/zsh.d/personal/aws_accounts.conf.template"

if [[ ! -f "$_config_file" ]]; then
  echo "❌ Configuration file not found: $_config_file"
  echo ""
  echo "Please create the configuration file with your AWS account details."
  if [[ -f "$_template_file" ]]; then
    echo "You can copy the template file as a starting point:"
    echo "  cp '$_template_file' '$_config_file'"
    echo "  # Then edit $_config_file with your account information"
  else
    echo "Create $_config_file with the following format:"
    echo "# Format: label|profile|account_id|k8s_context"
    echo "my-dev-account (123456789012)|my-dev-profile|123456789012|my-dev-k8s-context"
  fi
  __aws_sso_switcher__die "Configuration file required"
fi

# Read account mappings from config file
# Format: "label|profile|account_id|k8s_context"
_accounts=()
while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  _accounts+=("$line")
done <"$_config_file"

# Validate that we have at least one account configured
if [[ ${#_accounts[@]} -eq 0 ]]; then
  __aws_sso_switcher__die "No accounts found in configuration file: $_config_file"
fi

echo "Please select the AWS account you'd like to access:"
echo

# Build a simple printed menu (works the same in bash and zsh)
_i=1
for _row in "${_accounts[@]}"; do
  _label="${_row%%|*}"
  printf "%d) %s\n" "$_i" "$_label"
  _i=$((_i + 1))
done
echo

# Read choice in both bash and zsh
_choice=""
if [ -n "${ZSH_VERSION:-}" ]; then
  vared -p "#? " -c _choice
else
  read -r -p "#? " _choice
fi

# Validate numeric choice based on actual number of accounts
_max_choice=${#_accounts[@]}
if [[ ! "$_choice" =~ ^[0-9]+$ ]] || [[ "$_choice" -lt 1 ]] || [[ "$_choice" -gt "$_max_choice" ]]; then
  __aws_sso_switcher__die "Invalid choice. Please run again and select 1-$_max_choice."
fi

# Extract selected row
_idx=$((_choice - 1))
_selected="${_accounts[$((_idx + 1))]}" # arrays are 1-based in zsh when using ${array[index]}, but this expands correctly in both shells

# Parse fields
# label
_label="${_selected%%|*}"
_rest="${_selected#*|}"
# profile
_selected_profile="${_rest%%|*}"
_rest="${_rest#*|}"
# account id
_selected_account_id="${_rest%%|*}"
_rest="${_rest#*|}"
# k8s context (may be empty)
_k8s_context="${_rest}"

echo
echo "Selected account: ${_label}"
echo

# -----------------------
# VALIDATE PROFILE EXISTS
# -----------------------
echo "Validating AWS profile configuration..."
_profile_list=$(aws configure list-profiles 2>&1)
_list_exit_code=$?

if [[ $_list_exit_code -ne 0 ]]; then
  echo "❌ ERROR: Failed to list AWS profiles"
  echo "Error: $_profile_list"
  __aws_sso_switcher__die "Cannot read AWS configuration. Check if ~/.aws/config exists."
  return 1
fi

if ! echo "$_profile_list" | grep -q "^${_selected_profile}$"; then
  echo "❌ ERROR: Profile '${_selected_profile}' not found in ~/.aws/config"
  echo ""
  echo "Available profiles:"
  echo "$_profile_list" | sed 's/^/  - /'
  echo ""
  echo "To fix this, either:"
  echo "  1. Update aws_accounts.conf to use one of the available profiles above"
  echo "  2. Add the missing profile to ~/.aws/config:"
  echo ""
  echo "     [profile ${_selected_profile}]"
  echo "     sso_session = your-sso-session-name"
  echo "     sso_account_id = ${_selected_account_id}"
  echo "     sso_role_name = YourRoleName"
  echo "     region = us-east-1"
  echo ""
  echo "  Then define the sso-session (if not already present):"
  echo ""
  echo "     [sso-session your-sso-session-name]"
  echo "     sso_start_url = https://your-company.awsapps.com/start"
  echo "     sso_region = us-east-1"
  echo "     sso_registration_scopes = sso:account:access"
  __aws_sso_switcher__die "Profile configuration mismatch between aws_accounts.conf and ~/.aws/config"
  return 1
fi

# --------------------
# SSO LOGIN & PROFILE
# --------------------
# First, try to see if we already have a valid session
_sts_check=$(aws sts get-caller-identity --profile "$_selected_profile" 2>&1)
_sts_exit_code=$?

if [[ $_sts_exit_code -ne 0 ]]; then
  echo "Not logged in or session expired. Initiating SSO login..."
  # IMPORTANT: this must remain exactly "aws sso login" — global alias of "sso" would break it,
  # which is why we unaliased a global 'sso' at the top.
  _sso_output=$(aws sso login --profile "$_selected_profile" 2>&1)
  _sso_exit_code=$?

  if [[ $_sso_exit_code -ne 0 ]]; then
    echo ""
    echo "❌ SSO login failed"
    echo ""
    echo "Error details:"
    echo "$_sso_output" | sed 's/^/  /'
    echo ""
    echo "Common causes:"

    # Provide specific help based on error message
    if echo "$_sso_output" | grep -q "sso-session.*does not exist"; then
      _missing_session=$(echo "$_sso_output" | grep -oP 'sso-session.*does not exist: "\K[^"]+' || echo "unknown")
      echo "  ❗ Missing SSO session configuration"
      echo "     Add to ~/.aws/config:"
      echo ""
      echo "     [sso-session $_missing_session]"
      echo "     sso_start_url = https://your-company.awsapps.com/start"
      echo "     sso_region = us-east-1"
      echo "     sso_registration_scopes = sso:account:access"
    else
      echo "  - Invalid sso_start_url or sso_session in ~/.aws/config"
      echo "  - Network connectivity issues"
      echo "  - Incorrect sso_account_id or sso_role_name"
    fi

    echo ""
    echo "Your current profile configuration:"
    echo "  Profile: ${_selected_profile}"
    echo "  Account ID (expected): ${_selected_account_id}"
    __aws_sso_switcher__die "SSO login failed for profile '${_selected_profile}'"
    return 1
  fi
else
  echo "Already logged in to SSO."
fi

# Persist in current shell
export AWS_PROFILE="$_selected_profile"

# -------------
# VERIFY ACCESS
# -------------
echo
echo "Verifying access..."
_caller_json=$(aws sts get-caller-identity --profile "$_selected_profile" 2>&1)
_verify_exit_code=$?

if [[ $_verify_exit_code -ne 0 ]]; then
  echo ""
  echo "❌ Failed to verify AWS access"
  echo ""
  echo "Error details:"
  echo "$_caller_json" | sed 's/^/  /'
  echo ""
  echo "This usually means:"
  echo "  - SSO session is invalid or expired (try running the command again)"
  echo "  - Profile '${_selected_profile}' has incorrect configuration in ~/.aws/config"
  echo "  - The sso_account_id or sso_role_name in the profile doesn't match your permissions"
  echo ""
  echo "Profile details:"
  echo "  Profile: ${_selected_profile}"
  echo "  Expected Account ID: ${_selected_account_id}"
  __aws_sso_switcher__die "Failed to verify AWS access with profile '$_selected_profile'"
  return 1
fi

_account_id="$(echo "$_caller_json" | jq -r '.Account')"
_user_arn="$(echo "$_caller_json" | jq -r '.Arn')"

# Verify the account ID matches what we expect
if [[ "$_account_id" != "$_selected_account_id" ]]; then
  echo "⚠️  WARNING: Account ID mismatch!"
  echo "  Expected (from config): $_selected_account_id"
  echo "  Actual (from AWS):      $_account_id"
  echo ""
  echo "Please update your aws_accounts.conf file with the correct account ID."
  echo "Continuing with actual account ID: $_account_id"
  echo ""
fi

echo "✅ Successfully configured AWS access!"
echo "Account ID: $_account_id"
echo "User ARN:   $_user_arn"
echo "Profile:    $_selected_profile"
echo
echo "AWS_PROFILE is set to: $AWS_PROFILE"

# -------------------------
# KUBERNETES CONTEXT SWITCH
# -------------------------
if [ -n "$_k8s_context" ]; then
  echo
  echo "Switching Kubernetes context to '$_k8s_context'..."

  if command -v kubectx >/dev/null 2>&1; then
    if kubectx "$_k8s_context" >/dev/null 2>&1; then
      echo "✅ Switched to Kubernetes context: $_k8s_context"
    else
      echo "⚠️  Failed to switch with kubectx; trying kubectl..."
      if command -v kubectl >/dev/null 2>&1 && kubectl config use-context "$_k8s_context" >/dev/null 2>&1; then
        echo "✅ Switched to Kubernetes context via kubectl: $_k8s_context"
      else
        echo "⚠️  Failed to switch Kubernetes context: $_k8s_context"
      fi
    fi
  elif command -v kubectl >/dev/null 2>&1; then
    if kubectl config use-context "$_k8s_context" >/dev/null 2>&1; then
      echo "✅ Switched to Kubernetes context via kubectl: $_k8s_context"
    else
      echo "⚠️  Failed to switch Kubernetes context: $_k8s_context"
    fi
  else
    echo "ℹ️  Skipping Kubernetes context switch (neither kubectx nor kubectl found)"
  fi
else
  echo
  echo "ℹ️  No Kubernetes context associated with this account."
fi

echo
echo "You can now use AWS CLI and kubectl commands."
echo "To use this in other terminals:"
echo "  export AWS_PROFILE=\"$_selected_profile\""

