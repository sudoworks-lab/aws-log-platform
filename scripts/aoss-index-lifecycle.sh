#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/aoss-index-lifecycle.sh apply --root infra/live/<environment> [-- <terraform-options>]
  scripts/aoss-index-lifecycle.sh destroy --root infra/live/<environment> [-- <terraform-options>]

The live root must already be initialized with the intended backend configuration.
Pass shared Terraform options such as -var-file=terraform.tfvars after --.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  usage >&2
  exit 2
}

mode="${1:-}"
case "${mode}" in
  apply | destroy)
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  "")
    fail "mode is required"
    ;;
  *)
    fail "mode must be apply or destroy"
    ;;
esac

root_argument=""
terraform_arguments=()

while (($# > 0)); do
  case "$1" in
    --root)
      (($# >= 2)) || fail "--root requires a value"
      [[ -z "${root_argument}" ]] || fail "--root may be specified only once"
      root_argument="$2"
      shift 2
      ;;
    --)
      shift
      terraform_arguments=("$@")
      break
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown helper argument"
      ;;
  esac
done

[[ -n "${root_argument}" ]] || fail "--root is required; no environment is selected by default"

for argument in "${terraform_arguments[@]}"; do
  case "${argument}" in
    *provisioning_public_access_enabled*)
      fail "the helper owns provisioning_public_access_enabled"
      ;;
    -destroy | -target | -target=* | -replace | -replace=* | -refresh-only | -out | -out=*)
      fail "a Terraform option is incompatible with lifecycle orchestration"
      ;;
    -*)
      ;;
    *)
      fail "Terraform options must use -option=value form"
      ;;
  esac
done

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ "${root_argument}" = /* ]]; then
  root_candidate="${root_argument}"
else
  root_candidate="${repository_root}/${root_argument}"
fi

[[ -d "${root_candidate}" ]] || fail "live root does not exist: ${root_argument}"
terraform_root="$(cd "${root_candidate}" && pwd -P)"

[[ "$(dirname "${terraform_root}")" == "${repository_root}/infra/live" ]] ||
  fail "--root must identify one direct child of infra/live"
[[ -f "${terraform_root}/main.tf" && -f "${terraform_root}/variables.tf" ]] ||
  fail "--root is not a Terraform live root"
grep -q 'variable "provisioning_public_access_enabled"' "${terraform_root}/variables.tf" ||
  fail "live root does not declare provisioning_public_access_enabled"

terraform_binary="${TERRAFORM_BIN:-terraform}"
command -v "${terraform_binary}" >/dev/null 2>&1 || fail "Terraform was not found: ${terraform_binary}"

phase="not-started"
on_exit() {
  status=$?
  trap - EXIT
  if ((status != 0)); then
    case "${phase}" in
      provisioning)
        echo "ERROR: provisioning phase failed; the temporary public policy may exist. Inspect Terraform state and retry the helper." >&2
        ;;
      steady-state)
        echo "ERROR: private steady-state phase failed; the temporary public policy may still exist. Re-run apply after correcting the failure." >&2
        ;;
      destroy)
        echo "ERROR: destroy failed while provisioning access was enabled. Retry destroy, or run apply to return to private steady state if destruction is abandoned." >&2
        ;;
    esac
  fi
  exit "${status}"
}
trap on_exit EXIT

run_apply_phase() {
  desired_value="$1"
  phase_label="$2"
  phase="$3"

  echo "RUN: ${phase_label} ($(basename "${terraform_root}"))"
  "${terraform_binary}" -chdir="${terraform_root}" apply \
    "${terraform_arguments[@]}" \
    "-var=provisioning_public_access_enabled=${desired_value}"
}

case "${mode}" in
  apply)
    run_apply_phase true "enable temporary exact-collection public policy and apply index lifecycle" provisioning
    run_apply_phase false "remove temporary public policy" steady-state
    phase="complete"
    echo "PASS: AOSS index lifecycle completed; private-only steady state is restored."
    ;;
  destroy)
    run_apply_phase true "enable temporary exact-collection public policy before destroy" provisioning
    phase="destroy"
    echo "RUN: destroy with provisioning access enabled ($(basename "${terraform_root}"))"
    "${terraform_binary}" -chdir="${terraform_root}" destroy \
      "${terraform_arguments[@]}" \
      -var=provisioning_public_access_enabled=true
    phase="complete"
    echo "PASS: destroy completed, including removal of the temporary public policy."
    ;;
esac
