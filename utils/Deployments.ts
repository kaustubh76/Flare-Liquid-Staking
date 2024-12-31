import { ethers } from "ethers";
import { CONTRACT_ROLES, NETWORK_CONFIG } from "./Constants";

export async function verifyContract(
    hre: any,
    address: string,
    constructorArguments: any[]
) {
    try {
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: constructorArguments,
        });
    } catch (error) {
        console.error("Verification failed:", error);
    }
}

export async function deployContract(
    name: string,
    signer: ethers.Signer,
    args: any[] = []
) {
    const factory = await ethers.getContractFactory(name, signer);
    const contract = await factory.deploy(...args);
    await contract.deployed();
    return contract;
}
