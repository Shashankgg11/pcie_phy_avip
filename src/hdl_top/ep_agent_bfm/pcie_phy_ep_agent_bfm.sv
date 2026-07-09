`ifndef PCIE_PHY_EP_AGENT_BFM_INCLUDED_
`define PCIE_PHY_EP_AGENT_BFM_INCLUDED_

//--------------------------------------------------------------------------------------------
// Module: pcie_phy_ep_agent_bfm
// Instantiates the ep driver_bfm and monitor_bfm and wires them to the top-level pcie_phy_if
//--------------------------------------------------------------------------------------------
module pcie_phy_ep_agent_bfm #(parameter int EP_ID = 0)(pcie_phy_if intf);

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  pcie_phy_ep_driver_bfm pcie_phy_ep_drv_bfm_h (
    .aclk(intf.aclk), .aresetn(intf.aresetn),
    .ep_tx_symbol(intf.ep_tx_symbol), .ep_tx_electrical_idle(intf.ep_tx_electrical_idle),
    .rc_tx_symbol(intf.rc_tx_symbol), .rc_tx_electrical_idle(intf.rc_tx_electrical_idle),
    .ep_rx_receiver_present(intf.ep_rx_receiver_present),
    .ep_rx_electrical_idle_exit(intf.ep_rx_electrical_idle_exit)
  );

  pcie_phy_ep_monitor_bfm pcie_phy_ep_mon_bfm_h (
    .aclk(intf.aclk), .aresetn(intf.aresetn),
    .ep_tx_symbol(intf.ep_tx_symbol), .ep_tx_electrical_idle(intf.ep_tx_electrical_idle)
  );

  initial begin
    uvm_config_db#(virtual pcie_phy_ep_driver_bfm)::set(null, "*", "pcie_phy_ep_driver_bfm", pcie_phy_ep_drv_bfm_h);
    uvm_config_db#(virtual pcie_phy_ep_monitor_bfm)::set(null, "*", "pcie_phy_ep_monitor_bfm", pcie_phy_ep_mon_bfm_h);
  end

endmodule : pcie_phy_ep_agent_bfm

`endif
