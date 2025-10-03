.PHONY: test compile coverage deploy

test:
	forge test

compile:
	forge compile

coverage:
	forge coverage

deploy:
	forge deploy