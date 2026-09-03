#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_binary="${TERRAFORM_BIN:-terraform}"

if ! command -v "${terraform_binary}" >/dev/null 2>&1; then
  echo "ERROR: Terraform is required but was not found: ${terraform_binary}" >&2
  exit 127
fi

echo "RUN: terraform fmt -recursive -check"
"${terraform_binary}" -chdir="${repository_root}" fmt -recursive -check

verification_directory="$(mktemp -d)"
plugin_cache_directory="${verification_directory}/plugin-cache"
mkdir -p "${plugin_cache_directory}"

cleanup() {
  case "${verification_directory}" in
    /tmp/* | "${TMPDIR:-/tmp}"/*)
      rm -rf -- "${verification_directory}"
      ;;
    *)
      echo "WARN: refused to remove unexpected temporary path: ${verification_directory}" >&2
      ;;
  esac
}
trap cleanup EXIT

while IFS= read -r source_file; do
  relative_path="${source_file#"${repository_root}/"}"
  destination_file="${verification_directory}/${relative_path}"
  mkdir -p "$(dirname "${destination_file}")"
  cp "${source_file}" "${destination_file}"
done < <(
  find "${repository_root}/infra" -type f \
    \( -name '*.tf' -o -name '*.tftpl' -o -name '*.tftest.hcl' -o -name '.terraform.lock.hcl' \) -print
)

mapfile -t terraform_directories < <(
  find "${verification_directory}/infra/modules" "${verification_directory}/infra/live" \
    -mindepth 1 -maxdepth 1 -type d -print | sort
)

for terraform_directory in "${terraform_directories[@]}"; do
  display_path="${terraform_directory#"${verification_directory}/"}"
  echo "RUN: terraform init -backend=false (${display_path})"
  TF_IN_AUTOMATION=1 \
    TF_PLUGIN_CACHE_DIR="${plugin_cache_directory}" \
    CHECKPOINT_DISABLE=1 \
    "${terraform_binary}" -chdir="${terraform_directory}" init -backend=false -input=false -no-color

  echo "RUN: terraform validate (${display_path})"
  TF_IN_AUTOMATION=1 \
    TF_PLUGIN_CACHE_DIR="${plugin_cache_directory}" \
    CHECKPOINT_DISABLE=1 \
    "${terraform_binary}" -chdir="${terraform_directory}" validate -no-color

  if compgen -G "${terraform_directory}/tests/*.tftest.hcl" >/dev/null; then
    echo "RUN: terraform test (${display_path}, mock providers only)"
    TF_IN_AUTOMATION=1 \
      TF_PLUGIN_CACHE_DIR="${plugin_cache_directory}" \
      CHECKPOINT_DISABLE=1 \
      "${terraform_binary}" -chdir="${terraform_directory}" test -no-color
  fi
done

if command -v tflint >/dev/null 2>&1; then
  echo "INFO: tflint is available, but no repository-specific plugin policy is defined; tflint was not run."
else
  echo "SKIP: tflint is optional and is not installed."
fi

echo "PASS: local Terraform formatting, initialization, and validation completed."
echo "NOTE: no standalone plan, apply, AWS credential lookup, or AWS runtime validation was performed."
