`ifndef PCIE_PHY_EP_PKG_INCLUDED_
`define PCIE_PHY_EP_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package: pcie_phy_ep_pkg
// Includes all the files related to pcie_phy ep
//--------------------------------------------------------------------------------------------
package pcie_phy_ep_pkg;

  //-------------------------------------------------------
  // Import uvm package
  //-------------------------------------------------------
  `include "uvm_macros.svh"
  import uvm_pkg::*;

  // Import pcie_phy_globals_pkg
  import pcie_phy_globals_pkg::*;

  //-------------------------------------------------------
  // Include all other files
  //-------------------------------------------------------
  `include "pcie_phy_ep_agent_config.sv"
  `include "pcie_phy_ep_tx.sv"
  `include "pcie_phy_ep_seq_item_converter.sv"
  `include "pcie_phy_ep_cfg_converter.sv"
  `include "pcie_phy_ep_ltssm_sequencer.sv"
  `include "pcie_phy_ep_driver_proxy.sv"
  `include "pcie_phy_ep_monitor_proxy.sv"
  `include "pcie_phy_ep_coverage.sv"
  `include "pcie_phy_ep_agent.sv"

endpackage : pcie_phy_ep_pkg

`endif
