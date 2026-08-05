`ifndef PCIE_PHY_EP_AGENT_BFM_INCLUDED_
`define PCIE_PHY_EP_AGENT_BFM_INCLUDED_

import pcie_phy_pkg::*;

//--------------------------------------------------------------------------------------------
// Module: pcie_phy_ep_agent_bfm
// Instantiates the ep driver_bfm and monitor_bfm and wires them to this port's pcie_phy_if
//--------------------------------------------------------------------------------------------
module pcie_phy_ep_agent_bfm #(parameter int EP_ID = 0)(pcie_phy_if intf);

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  pcie_phy_ep_driver_bfm pcie_phy_ep_drv_bfm_h (
    .pclk(intf.pclk), .preset_n(intf.preset_n),
    .RX_P(intf.TX_P[PCIE_MAX_LANES-1:0]), .RX_N(intf.TX_N[PCIE_MAX_LANES-1:0])
  );

  pcie_phy_ep_monitor_bfm pcie_phy_ep_mon_bfm_h (
    .pclk(intf.pclk), .preset_n(intf.preset_n),
    .RX_P(intf.TX_P[PCIE_MAX_LANES-1:0]), .RX_N(intf.TX_N[PCIE_MAX_LANES-1:0])
  );

  //Reserved/unused lanes above PCIE_MAX_LANES: pcie_phy_if's buses are a fixed 32 bits wide;
  //tie off whatever this profile doesn't use so TX_P/TX_N are never partially undriven.
  assign intf.TX_P[31:PCIE_MAX_LANES] = '0;
  assign intf.TX_N[31:PCIE_MAX_LANES] = '0;

  initial begin
    $display("[%0t] PCIE_PHY_EP_AGENT_BFM : Instantiated - registering driver_bfm/monitor_bfm handles into config_db", $time);
    uvm_config_db#(virtual pcie_phy_ep_driver_bfm)::set(null, "*", "pcie_phy_ep_driver_bfm", pcie_phy_ep_drv_bfm_h);
    uvm_config_db#(virtual pcie_phy_ep_monitor_bfm)::set(null, "*", "pcie_phy_ep_monitor_bfm", pcie_phy_ep_mon_bfm_h);
  end

endmodule : pcie_phy_ep_agent_bfm

`endif
