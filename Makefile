# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env
.PHONY: build build-optimised test anvil deploy deploy-simple-flip fund-function flip print-request set-mr-enclave build-rust-function publish-rust-function measurement-rust-function

all: test

####################################################
# Environment Variables and Utils
####################################################

ALLOWED_CHAINS := arbitrum arbitrumGoerli base baseGoerli core coreGoerli optimism optimismGoerli localhost

CHAIN ?= localhost
ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# This allows us to pass the anvil privateKey and RPC if were using a local network
ifeq ($(CHAIN),localhost)
	FORGE_SCRIPT_ARGS = --rpc-url http://localhost:8545 --private-key $(ANVIL_PRIVATE_KEY)
else
	FORGE_SCRIPT_ARGS = --rpc-url ${CHAIN}
endif

check_chain_env:
ifeq ($(filter $(CHAIN),$(ALLOWED_CHAINS)),)
	$(error CHAIN ('$(CHAIN)') is not set to an allowed value, must be one of '$(ALLOWED_CHAINS)')
else
	@echo CHAIN: ${CHAIN}
endif

check_priv_key_env:
ifeq ($(strip $(PRIVATE_KEY)),)
	$(error PRIVATE_KEY is not set)
endif

# check_chain_not_mainnet:
# ifeq ($(suffix $(CHAIN)),-mainnet)
# 	$(error "CHAIN ends with -mainnet which is not allowed! You should use a more secure deployment method.")
# endif

check_docker_env:
ifeq ($(strip $(DOCKER_IMAGE_NAME)),)
	$(error DOCKER_IMAGE_NAME is not set)
else
	@echo DOCKER_IMAGE_NAME: ${DOCKER_IMAGE_NAME}
endif

####################################################
# Forge Tasks
####################################################

remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"
# Clean the repo
clean  :; forge clean
install :; forge install foundry-rs/forge-std && forge install marktoda/forge-gas-snapshot && forge install switchboard-xyz/switchboard-contracts && forge install Arachnid/solidity-stringutils
clear-addresses :; jq '.[] .contractAddress = "0x0000000000000000000000000000000000000000"' deployments.json > tmp.json && mv tmp.json deployments.json

build:; forge build
build-optimised :; forge build --optimize
snapshot :; forge snapshot
test-gasreport 	:; forge test --gas-report

anvil :; anvil -m 'test test test test test test test test test test test junk'

test: check_chain_env check_priv_key_env
ifeq ($(CHAIN),localhost)
	forge test -vvvv --ffi
else
	forge test -vvvv --ffi --fork-url $(CHAIN)
endif

deploy: check_chain_env check_priv_key_env
ifeq ($(CHAIN),localhost)
	forge script script/Deploy.s.sol:DeployCoinFlip ${FORGE_SCRIPT_ARGS} --ffi -vvvv --broadcast
else
# Need to add the '--verify'
	forge script script/Deploy.s.sol:DeployCoinFlip ${FORGE_SCRIPT_ARGS} --verify --ffi --legacy -vvvvvv --broadcast
endif

####################################################
# Forge Scripts
####################################################

create-function: check_chain_env check_priv_key_env
	forge script script/switchboard/CreateFunction.s.sol:CreateFunction ${FORGE_SCRIPT_ARGS} --broadcast -vvvv --legacy --ffi

fund-function: check_chain_env check_priv_key_env
	forge script script/switchboard/FundFunction.s.sol:FundFunction ${FORGE_SCRIPT_ARGS} --broadcast -vv --legacy --ffi

print-function: check_chain_env
	forge script script/switchboard/PrintFunction.s.sol:PrintFunction ${FORGE_SCRIPT_ARGS} -v --legacy --ffi

flip: check_chain_env check_priv_key_env
	forge script script/Flip.s.sol:Flip ${FORGE_SCRIPT_ARGS} --broadcast -vvvvvv --legacy --ffi

print-request: check_chain_env
	forge script script/Print.s.sol:PrintRequest ${FORGE_SCRIPT_ARGS} -v --legacy --ffi

print-queue: check_chain_env
	forge script script/switchboard/PrintQueue.s.sol:PrintQueue ${FORGE_SCRIPT_ARGS} -v --legacy --ffi

sync-function: check_chain_env check_priv_key_env
	forge script script/switchboard/ResetFunctionStatus.s.sol:ResetFunctionStatus ${FORGE_SCRIPT_ARGS} -vv --broadcast --legacy --ffi

sync-function-all: check_priv_key_env
	@echo "Setting MrEnclave for all deployments"; \
	CHAIN=arbitrumGoerli forge script script/switchboard/ResetFunctionStatus.s.sol:ResetFunctionStatus --rpc-url arbitrumGoerli --broadcast -v --legacy --ffi & \
	CHAIN=optimismGoerli forge script script/switchboard/ResetFunctionStatus.s.sol:ResetFunctionStatus --rpc-url optimismGoerli --broadcast -v --legacy --ffi & \
	CHAIN=baseGoerli forge script script/switchboard/ResetFunctionStatus.s.sol:ResetFunctionStatus --rpc-url baseGoerli --broadcast -v --legacy --ffi & \
	CHAIN=coreGoerli forge script script/switchboard/ResetFunctionStatus.s.sol:ResetFunctionStatus --rpc-url coreGoerli --broadcast -v --legacy --ffi & \
	wait; \
	echo "Done."

set-mr-enclave: check_chain_env check_priv_key_env measurement-rust-function
	forge script script/switchboard/SetMrEnclave.s.sol:SetMrEnclave ${FORGE_SCRIPT_ARGS} --broadcast -vvvv --legacy --ffi

set-mr-enclave-all: check_priv_key_env measurement-rust-function
	@echo "Setting MrEnclave for all deployments"; \
	CHAIN=arbitrumGoerli forge script script/switchboard/SetMrEnclave.s.sol:SetMrEnclave --rpc-url arbitrumGoerli --broadcast -v --legacy --ffi & \
	CHAIN=optimismGoerli forge script script/switchboard/SetMrEnclave.s.sol:SetMrEnclave --rpc-url optimismGoerli --broadcast -v --legacy --ffi & \
	CHAIN=baseGoerli forge script script/switchboard/SetMrEnclave.s.sol:SetMrEnclave --rpc-url baseGoerli --broadcast -v --legacy --ffi & \
	CHAIN=coreGoerli forge script script/switchboard/SetMrEnclave.s.sol:SetMrEnclave --rpc-url coreGoerli --broadcast -v --legacy --ffi & \
	wait; \
	echo "Done."

####################################################
# Switchboard Function Tasks
####################################################

build-rust-function: check_docker_env
	DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64 --pull -f ./switchboard-function/rust/Dockerfile -t ${DOCKER_IMAGE_NAME}:rust --load ./switchboard-function/rust/

publish-rust-function: check_docker_env
	DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64 --pull -f ./switchboard-function/rust/Dockerfile -t ${DOCKER_IMAGE_NAME}:latest -t ${DOCKER_IMAGE_NAME}:rust --push ./switchboard-function/rust/

measurement-rust-function: check_docker_env
	@docker run -d --platform=linux/amd64 -q --name=my-switchboard-function ${DOCKER_IMAGE_NAME}:rust
	@docker cp my-switchboard-function:/measurement.txt ./measurement.txt
	@echo -n 'MrEnclve: '
	@cat measurement.txt
	@docker stop my-switchboard-function > /dev/null
	@docker rm my-switchboard-function > /dev/null

build-typescript-function: check_docker_env
	DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64 --pull -f ./switchboard-function/typescript/Dockerfile -t ${DOCKER_IMAGE_NAME}:typescript --load ./switchboard-function/typescript/

publish-typescript-function: check_docker_env
	DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64 --pull -f ./switchboard-function/typescript/Dockerfile -t ${DOCKER_IMAGE_NAME}:typescript --push ./switchboard-function/typescript/

measurement-typescript-function: check_docker_env
	@docker run -d --platform=linux/amd64 -q --name=my-switchboard-function ${DOCKER_IMAGE_NAME}:typescript
	@docker cp my-switchboard-function:/measurement.txt ./measurement.typescript.txt
	@echo -n 'MrEnclve: '
	@cat measurement.typescript.txt
	@docker stop my-switchboard-function > /dev/null
	@docker rm my-switchboard-function > /dev/null
