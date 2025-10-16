.PHONY: test compile coverage deploy

-include .env

test:
	forge test

clean:
	forge clean

compile:
	forge compile

size:
	forge build --sizes

coverage:
	forge coverage --ir-minimum

deploy:
	forge script script/NusaHub.s.sol:NusaHubScript --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify --verifier ${VERIFIER} --verifier-url ${VERIFIER_URL}