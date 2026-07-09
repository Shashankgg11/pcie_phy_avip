`ifndef PCIE_PHY_IF_INCLUDED_
`define PCIE_PHY_IF_INCLUDED_

// Import pcie_phy_globals_pkg
import pcie_phy_globals_pkg::*;

//--------------------------------------------------------------------------------------------
// Interface: pcie_phy_if
// Declaration of pin-level signals for the PCIe Gen6 PHY link (RC <-> EP direct-connect)
//--------------------------------------------------------------------------------------------
interface pcie_phy_if #(parameter int NUM_LANES = 4) (input aclk, input aresetn);

  //RC -> EP direction
  logic [7:0] rc_tx_symbol            [NUM_LANES];
  logic       rc_tx_electrical_idle    [NUM_LANES];

  //EP -> RC direction
  logic [7:0] ep_tx_symbol            [NUM_LANES];
  logic       ep_tx_electrical_idle    [NUM_LANES];

  //Detect-state receiver-detect results (analog, modeled as single bit)
  logic       rc_rx_receiver_present   [NUM_LANES];
  logic       ep_rx_receiver_present   [NUM_LANES];

  //Electrical Idle Exit flags
  logic       rc_rx_electrical_idle_exit [NUM_LANES];
  logic       ep_rx_electrical_idle_exit [NUM_LANES];

  // TODO: scrambler LFSR taps, additional Gen6 sideband if needed

endinterface : pcie_phy_if

`endif
