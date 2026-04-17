.PHONY: install test test-unit test-integration deps

install:
	bash install.sh

deps:
	brew install bats-core jq

test: test-unit test-integration

test-unit:
	bats tests/unit/ --recursive

test-integration:
	bats tests/integration/ --recursive
