
certora: FORCE
	PATH=${PWD}/certora:${PATH} certoraRun \
		--solc ${SOLC_PATH} \
		--solc_optimize 200 \
		--solc_via_ir \
		--solc_evm_version paris \
		src/SlowerWallet.sol \
		certora/TokenMock.sol \
		--packages "@openzeppelin=lib/openzeppelin-contracts/contracts" \
		--verify SlowerWallet:certora/SlowerWallet.spec \
		$(if $(rule),--rule $(rule),) \

FORCE:
