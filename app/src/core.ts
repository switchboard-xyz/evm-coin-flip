export const core = {
  id: 1116,
  name: "Core",
  network: "core",
  nativeCurrency: {
    decimals: 18,
    name: "Core",
    symbol: "CORE",
  },
  rpcUrls: {
    default: {
      http: ["https://rpc.coredao.org"],
    },
    public: {
      http: ["https://rpc.coredao.org"],
    },
  },
  blockExplorers: {
    etherscan: {
      name: "Etherscan",
      url: "https://scan.coredao.org",
    },
    default: {
      name: "Etherscan",
      url: "https://scan.coredao.org",
    },
  },
};

export const coreGoerli = {
  id: 1115,
  name: "Core Goerli",
  network: "core-goerli",
  nativeCurrency: {
    decimals: 18,
    name: "tCore",
    symbol: "tCORE",
  },
  rpcUrls: {
    default: {
      http: ["https://rpc.test.btcs.network"],
    },
    public: {
      http: ["https://rpc.test.btcs.network"],
    },
  },
  blockExplorers: {
    etherscan: {
      name: "Etherscan",
      url: "https://scan.test.btcs.network",
    },
    default: {
      name: "Etherscan",
      url: "https://scan.test.btcs.network",
    },
  },
};
