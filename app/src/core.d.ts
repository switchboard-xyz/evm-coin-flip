export declare const core: {
  readonly id: 1116;
  readonly name: "Core";
  readonly network: "core";
  readonly nativeCurrency: {
    readonly decimals: 18;
    readonly name: "Core";
    readonly symbol: "CORE";
  };
  readonly rpcUrls: {
    readonly default: {
      readonly http: readonly ["https://rpc.coredao.org"];
    };
    readonly public: {
      readonly http: readonly ["https://rpc.coredao.org"];
    };
  };
  readonly blockExplorers: {
    readonly etherscan: {
      readonly name: "Etherscan";
      readonly url: "https://scan.coredao.org";
    };
    readonly default: {
      readonly name: "Etherscan";
      readonly url: "https://scan.coredao.org";
    };
  };
};

export declare const coreGoerli: {
  readonly id: 1115;
  readonly name: "Core Goerli";
  readonly network: "core-goerli";
  readonly nativeCurrency: {
    readonly decimals: 18;
    readonly name: "tCore";
    readonly symbol: "tCORE";
  };
  readonly rpcUrls: {
    readonly default: {
      readonly http: readonly ["https://rpc.test.btcs.network"];
    };
    readonly public: {
      readonly http: readonly ["https://rpc.test.btcs.network"];
    };
  };
  readonly blockExplorers: {
    readonly etherscan: {
      readonly name: "Etherscan";
      readonly url: "https://scan.test.btcs.network";
    };
    readonly default: {
      readonly name: "Etherscan";
      readonly url: "https://scan.test.btcs.network";
    };
  };
};
