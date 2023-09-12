import * as React from "react";

import { useAccount } from "wagmi";

import Box from "@mui/material/Box";
import { CoinFlip } from "./components/CoinFlip";
import Typography from "@mui/material/Typography";
import { AppBar } from "./AppBar";

export function App() {
  const { isConnected } = useAccount();

  return (
    <>
      <AppBar />

      {!isConnected && (
        <Box sx={{ minHeight: { md: "100px", xs: "4rem" } }}>
          <Typography>
            Please connect a wallet to interact with the app
          </Typography>
        </Box>
      )}

      {isConnected && (
        <>
          <hr />
          <h2>Coin Flip</h2>
          <CoinFlip />
          <hr />
        </>
      )}
    </>
  );
}
