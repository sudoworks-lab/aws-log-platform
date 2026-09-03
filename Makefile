.PHONY: fmt verify

fmt:
	terraform fmt -recursive

verify:
	./scripts/verify.sh

