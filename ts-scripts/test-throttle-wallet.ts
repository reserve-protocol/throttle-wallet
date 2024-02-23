import { formatEther } from 'ethers'
import hre, { ethers } from 'hardhat'
import { whileImpersonating } from '../utils/impersonation'
import { advanceBlocks, advanceTime } from '../utils/time'

// This prints an MD table of all the collateral plugin parameters
// Usage: npx hardhat run --network mainnet scripts/collateral-params.ts
async function main() {
    const [deployer] = await ethers.getSigners()

    const oneWeek = 60*60*24*7

    const rsrAddress = '0x320623b8E4fF03373931769A31Fc52A4E78B5d70'
    const rsr = await ethers.getContractAt('IERC20', rsrAddress)

    const ADMIN = "0x27e6DC36e7F05d64B6ab284338243982b0e26d78"
    const USER = "0x7cc1bfAB73bE4E02BB53814d1059A98cF7e49644"
    const slowWalletAddress = "0x6bab6EB87Aa5a1e4A8310C73bDAAA8A5dAAd81C1"
    const sw = await ethers.getContractAt('ISlowWallet', slowWalletAddress)
    const swOwner = await sw.owner()

    const swBal = await rsr.balanceOf(slowWalletAddress)
    const veRsrFunds = 20000000000n * 10n ** 18n
    const rsrRemainder = swBal - veRsrFunds

    const twAddress = "0x0774dF07205a5E9261771b19afa62B6e757f7eF8"
    const tw = await ethers.getContractAt('SlowerWallet', twAddress)

    const swBalBeforeMigration = await rsr.balanceOf(slowWalletAddress)
    const twBalBeforeMigration = await rsr.balanceOf(twAddress)
    console.log("SlowWallet balance before migration: ", formatEther(swBalBeforeMigration))
    console.log("SlowerWallet balance before migration: ", formatEther(twBalBeforeMigration))

    // migrate
    await whileImpersonating(hre, swOwner, async (swo) => {
        // await sw.connect(swo).propose(twAddress, rsrRemainder, "Migrate to SlowerWallet");
        const twoWeeks = 60*60*24*7*2
        await advanceTime(hre, twoWeeks + 1)
        await advanceBlocks(hre, twoWeeks / 12 + 1);
        await sw.connect(swo).confirm(0, twAddress, rsrRemainder);
    })

    const swBalAfterMigration = await rsr.balanceOf(slowWalletAddress)
    const twBalAfterMigration = await rsr.balanceOf(twAddress)

    console.log("SlowWallet balance after migration: ", formatEther(swBalAfterMigration))
    console.log("SlowerWallet balance after migration: ", formatEther(twBalAfterMigration))

    const userBalBeforeWithdrawals = await rsr.balanceOf(USER)
    console.log("User balance before withdrawals: ", formatEther(userBalBeforeWithdrawals))

    // test withdrawals
    await whileImpersonating(hre, USER, async (uo) => {
        await tw.connect(uo).initiateWithdrawal(1000000000n * 10n ** 18n, USER)
        await advanceTime(hre, oneWeek * 2 + 1)
        await advanceBlocks(hre, oneWeek * 2 / 12 + 1);
        await tw.connect(uo).initiateWithdrawal(500000000n * 10n ** 18n, USER)
        await advanceTime(hre, oneWeek * 4)
        await advanceBlocks(hre, oneWeek * 4 / 12);

        await tw.connect(uo).completeWithdrawal(0)
        await tw.connect(uo).completeWithdrawal(1)
    })

    const twBalAfterWithdrawals = await rsr.balanceOf(twAddress)
    console.log("SlowerWallet balance after withdrawals: ", formatEther(twBalAfterWithdrawals))

    const userBalAfterWithdrawals = await rsr.balanceOf(USER)
    console.log("User balance after withdrawals: ", formatEther(userBalAfterWithdrawals))

    // cancel withdrawal
    await whileImpersonating(hre, USER, async (uo) => {
        await tw.connect(uo).initiateWithdrawal(1000000000n * 10n ** 18n, USER)
        await advanceTime(hre, oneWeek * 2 + 1)
        await advanceBlocks(hre, oneWeek * 2 / 12 + 1);
    })

    await whileImpersonating(hre, ADMIN, async (ao) => {
        await tw.connect(ao).cancelWithdrawal(2)
    })

    await whileImpersonating(hre, USER, async (uo) => {
        try {
            await tw.connect(uo).completeWithdrawal(2)
        } catch (e) {
            console.log("Withdrawal cancelled, call failed")
        }

        await advanceTime(hre, oneWeek * 2 + 1)

        try {
            await tw.connect(uo).completeWithdrawal(2)
        } catch (e) {
            console.log("Withdrawal cancelled, call failed")
        }
    })

    await whileImpersonating(hre, ADMIN, async (ao) => {
        await tw.connect(ao).changeUser(deployer.address)
    })

    await whileImpersonating(hre, USER, async (uo) => {
        try {
            await tw.connect(uo).initiateWithdrawal(1000000000n * 10n ** 18n, deployer.address)
        } catch (e) {
            console.log("User changed, call failed")
        }
    })

    await tw.connect(deployer).initiateWithdrawal(1000000000n * 10n ** 18n, deployer.address)
    console.log('done')
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
