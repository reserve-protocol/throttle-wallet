
certora: FORCE
	PATH=${PWD}/certora:${PATH} certoraRun \
		--solc __NO_CONFLICT__solc-0.8.21 \
		--solc_optimize 200 \
		--solc_via_ir \
		--solc_evm_version paris \
		--rule_sanity basic \
		src/ThrottleWallet.sol \
		--packages "@openzeppelin=lib/openzeppelin-contracts/contracts" \
		--verify ThrottleWallet:certora/ThrottleWallet.spec \
		$(if $(rule),--rule $(rule),)

FORCE:
