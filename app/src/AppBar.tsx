import { default as MuiAppBar } from "@mui/material/AppBar";
import Avatar from "@mui/material/Avatar";
import Box from "@mui/material/Box";
import Button from "@mui/material/Button";
import IconButton from "@mui/material/IconButton";
import Menu from "@mui/material/Menu";
import Toolbar from "@mui/material/Toolbar";
import Tooltip from "@mui/material/Tooltip";
import Typography from "@mui/material/Typography";
import * as React from "react";
import { useState } from "react";
import {
  useAccount,
  useBalance,
  useConnect,
  useDisconnect,
  useSwitchNetwork,
} from "wagmi";
import WalletIcon from "@mui/icons-material/Wallet";
import PowerSettingsNewIcon from "@mui/icons-material/PowerSettingsNew";

export function AppBar() {
  const [anchorElNav, setAnchorElNav] = useState<null | HTMLElement>(null);
  const [anchorElUser, setAnchorElUser] = useState<null | HTMLElement>(null);

  const handleOpenNavMenu = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorElNav(event.currentTarget);
  };
  const handleOpenUserMenu = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorElUser(event.currentTarget);
  };

  const handleCloseNavMenu = () => {
    setAnchorElNav(null);
  };

  const handleCloseUserMenu = () => {
    setAnchorElUser(null);
  };

  //
  const {
    chains,
    error: switchNetworkError,
    isLoading: switchNetworkLoading,
    switchNetwork,
    pendingChainId,
  } = useSwitchNetwork();
  const { connector, isConnected, address } = useAccount();
  const { connect, connectors, error, isLoading, pendingConnector } =
    useConnect();
  const { disconnect } = useDisconnect();
  const {
    data: isBalanceData,
    isError: isBalanceError,
    isLoading: isBalanceLoading,
  } = useBalance({ address, watch: true });

  return (
    <MuiAppBar position="static">
      <Toolbar disableGutters>
        <Avatar sx={{ m: 2 }}>S</Avatar>
        <Box flexGrow={1}>
          <Typography
            variant="h6"
            noWrap
            component="div"
            sx={{
              mr: 2,
              display: { xs: "none", md: "flex" },
              fontFamily: "monospace",
              fontWeight: 700,
              letterSpacing: ".3rem",
              color: "inherit",
              textDecoration: "none",
            }}
          >
            Switchboard Coin Flip
          </Typography>
          <Typography
            variant="h5"
            noWrap
            component="div"
            sx={{
              mr: 2,
              display: { xs: "flex", md: "none" },
              flexGrow: 1,
              fontFamily: "monospace",
              fontWeight: 700,
              letterSpacing: ".3rem",
              color: "inherit",
              textDecoration: "none",
            }}
          >
            Switchboard Coin Flip
          </Typography>
        </Box>

        {!isConnected && (
          <Box>
            <Tooltip title="Open wallet settings">
              <IconButton
                size="large"
                edge="start"
                color="inherit"
                aria-label="menu"
                sx={{ mr: 2, color: "white" }}
                onClick={handleOpenUserMenu}
              >
                <WalletIcon />
                <Typography
                  variant="button"
                  sx={{ ml: "1rem", color: "white" }}
                >
                  Connect
                </Typography>
              </IconButton>
            </Tooltip>
            <Menu
              sx={{ mt: "45px" }}
              id="menu-appbar"
              anchorEl={anchorElUser}
              anchorOrigin={{
                vertical: "top",
                horizontal: "right",
              }}
              keepMounted
              transformOrigin={{
                vertical: "top",
                horizontal: "right",
              }}
              open={Boolean(anchorElUser)}
              onClose={handleCloseUserMenu}
            >
              <Box sx={{ textAlign: "center" }}>
                <Typography variant="button" sx={{ fontWeight: 600 }}>
                  Connect
                </Typography>
              </Box>
              {connectors
                .filter((x) => x.ready && x.id !== connector?.id)
                .map((x) => (
                  <Box key={"connector" + x.id}>
                    <Button onClick={() => connect({ connector: x })}>
                      {x.name}
                      {isLoading &&
                        x.id === pendingConnector?.id &&
                        " (connecting)"}
                    </Button>
                  </Box>
                ))}
              {/* NETWORKS */}
              <Box sx={{ textAlign: "center" }}>
                <Typography variant="button" sx={{ fontWeight: 600 }}>
                  Networks
                </Typography>
              </Box>
              {chains.map((x) => (
                <Box key={"chain" + x.id}>
                  <Button onClick={() => switchNetwork?.(x.id)}>
                    {x.name}
                    {switchNetworkLoading &&
                      x.id == pendingChainId &&
                      " (switching)"}
                  </Button>
                </Box>
              ))}
            </Menu>
          </Box>
        )}

        {isConnected && (
          <>
            <Box>
              <Typography
                variant="button"
                sx={{ color: "white", fontWeight: 700 }}
              >
                Balance:
              </Typography>
              &emsp;
              {!isBalanceLoading && isBalanceData && (
                <Typography variant="button" sx={{ color: "white" }}>
                  {Number.parseFloat(isBalanceData.formatted).toFixed(4)}&nbsp;
                  {isBalanceData.symbol}
                </Typography>
              )}
            </Box>
            <Box>
              <IconButton
                size="large"
                edge="start"
                color="inherit"
                aria-label="disconnect-wallet"
                sx={{ ml: "1rem", color: "white" }}
                onClick={() => disconnect()}
              >
                <PowerSettingsNewIcon />
                <Typography variant="button" sx={{ color: "white" }}>
                  Disconnect
                </Typography>
              </IconButton>
            </Box>
          </>
        )}
      </Toolbar>
    </MuiAppBar>
  );
}
