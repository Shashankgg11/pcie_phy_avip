`ifndef PCIE_PHY_RC_AGENT_BFM_INCLUDED_
`define PCIE_PHY_RC_AGENT_BFM_INCLUDED_

import pcie_phy_pkg::*;

// Module for RC agent BFM
// It contains the RC driver BFM and monitor BFM and connects them to the PCIe PHY interface
module pcie_phy_rc_agent_bfm #(parameter int RC_ID = 0)(pcie_phy_if intf);

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  pcie_phy_rc_driver_bfm pcie_phy_rc_drv_bfm_h (
    .pclk(intf.pclk), .preset_n(intf.preset_n),
    .TX_P(intf.TX_P[PCIE_MAX_LANES-1:0]), .TX_N(intf.TX_N[PCIE_MAX_LANES-1:0]),
    .RX_P(intf.RX_P[PCIE_MAX_LANES-1:0]), .RX_N(intf.RX_N[PCIE_MAX_LANES-1:0])
  );

  pcie_phy_rc_monitor_bfm pcie_phy_rc_mon_bfm_h (
    .pclk(intf.pclk), .preset_n(intf.preset_n),
    .RX_P(intf.RX_P[PCIE_MAX_LANES-1:0]), .RX_N(intf.RX_N[PCIE_MAX_LANES-1:0])
  );

  // The interface has 32 lanes, so set the unused lanes to 0
  // This makes sure the unused TX lanes are not left without a value
  assign intf.TX_P[31:PCIE_MAX_LANES] = '0;
  assign intf.TX_N[31:PCIE_MAX_LANES] = '0;

  initial begin
    $display("[%0t] PCIE_PHY_RC_AGENT_BFM : Instantiated - registering driver_bfm/monitor_bfm handles into config_db", $time);
    uvm_config_db#(virtual pcie_phy_rc_driver_bfm)::set(null, "*", "pcie_phy_rc_driver_bfm", pcie_phy_rc_drv_bfm_h);
    uvm_config_db#(virtual pcie_phy_rc_monitor_bfm)::set(null, "*", "pcie_phy_rc_monitor_bfm", pcie_phy_rc_mon_bfm_h);
  end

endmodule : pcie_phy_rc_agent_bfm

`endif
