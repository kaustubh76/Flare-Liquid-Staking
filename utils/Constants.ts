export const NETWORK_CONFIG = {
    mainnet: {
        chainId: 1,
        confirmations: 6,
        blockTime: 12
    },
    flare: {
        chainId: 14,
        confirmations: 2,
        blockTime: 3
    },
    songbird: {
        chainId: 19,
        confirmations: 2,
        blockTime: 3
    }
};

export const CONTRACT_ROLES = {
    ADMIN_ROLE: "0x0000000000000000000000000000000000000000000000000000000000000000",
    MINTER_ROLE: "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    EXECUTOR_ROLE: "0x7df25b80a735481726715f23762c442a7a5dd1f57687a1a58c213f5c7af0717b",
    SLASHER_ROLE: "0x7df25b80a735481726715f23762c442a7a5dd1f57687a1a58c213f5c7af0717c"
};