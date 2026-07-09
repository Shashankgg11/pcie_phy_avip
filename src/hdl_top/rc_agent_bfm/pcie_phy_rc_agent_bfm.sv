`ifndef PCIE_PHY_RC_AGENT_BFM_INCLUDED_
`define PCIE_PHY_RC_AGENT_BFM_INCLUDED_

//--------------------------------------------------------------------------------------------
// Module: pcie_phy_rc_agent_bfm
// Instantiates the rc driver_bfm and monitor_bfm and wires them to the top-level pcie_phy_if
//--------------------------------------------------------------------------------------------
module pcie_phy_rc_agent_bfm #(parameter int RC_ID = 0)(pcie_phy_if intf);

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  pcie_phy_rc_driver_bfm pcie_phy_rc_drv_bfm_h (
    .aclk(intf.aclk), .aresetn(intf.aresetn),
    .rc_tx_symbol(intf.rc_tx_symbol), .rc_tx_electrical_idle(intf.rc_tx_electrical_idle),
    .ep_tx_symbol(intf.ep_tx_symbol), .ep_tx_electrical_idle(intf.ep_tx_electrical_idle),
    .rc_rx_receiver_present(intf.rc_rx_receiver_present),
    .rc_rx_electrical_idle_exit(intf.rc_rx_electrical_idle_exit)
  );

  pcie_phy_rc_monitor_bfm pcie_phy_rc_mon_bfm_h (
    .aclk(intf.aclk), .aresetn(intf.aresetn),
    .rc_tx_symbol(intf.rc_tx_symbol), .rc_tx_electrical_idle(intf.rc_tx_electrical_idle)
  );

  initial begin
    uvm_config_db#(virtual pcie_phy_rc_driver_bfm)::set(null, "*", "pcie_phy_rc_driver_bfm", pcie_phy_rc_drv_bfm_h);
    uvm_config_db#(virtual pcie_phy_rc_monitor_bfm)::set(null, "*", "pcie_phy_rc_monitor_bfm", pcie_phy_rc_mon_bfm_h);
  end

endmodule : pcie_phy_rc_agent_bfm

`endif
