.PHONY: test compile coverage deploy

test:
	forge test

compile:
	forge compile

coverage:
	forge coverage --ir-minimum


deploy:
	forge deploy