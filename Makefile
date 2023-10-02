
certora: FORCE
	PATH=${PWD}/certora:${PATH} certoraRun \
		--solc ${SOLC_PATH} \
		--solc_optimize 200 \
		--solc_via_ir \
		--solc_evm_version paris \
		src/ThrottleWallet.sol \
		certora/TokenMock.sol \
		--packages "@openzeppelin=lib/openzeppelin-contracts/contracts" \
		--verify ThrottleWallet:certora/ThrottleWallet.spec \
		$(if $(rule),--rule $(rule),) \

FORCE:
