`ifndef PCIE_PHY_IF_INCLUDED_
`define PCIE_PHY_IF_INCLUDED_

//--------------------------------------------------------------------------------------------
// Interface: pcie_phy_if
// Per-port physical-pin view of the PCIe Gen6 differential link (RC <-> EP direct-connect).
// One instance of this interface represents ONE port's own pins:
//   TX_P/TX_N - this port's serial transmit pair, bit-per-lane, driven by this port's own
//               driver_bfm (pipe_tx_p/pipe_tx_n)
//   RX_P/RX_N - this port's serial receive pair, bit-per-lane, driven by the LINK PARTNER's
//               TX_P/TX_N (cross-wired in hdl_top, not internally)
// ref_clk/d_clk/rst_n are plain internal nets (no port list) - hdl_top drives them from
// outside via hierarchical/continuous assignment, e.g. assign rc_intf.d_clk = d_clk;
//--------------------------------------------------------------------------------------------
interface pcie_phy_if();
  logic ref_clk;
  logic d_clk;
  logic rst_n;
  logic [31:0] TX_P, TX_N;
  logic [31:0] RX_P, RX_N;
endinterface : pcie_phy_if

`endif
