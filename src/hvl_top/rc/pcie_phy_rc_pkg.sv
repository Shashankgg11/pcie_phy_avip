`ifndef PCIE_PHY_RC_PKG_INCLUDED_
`define PCIE_PHY_RC_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package: pcie_phy_rc_pkg
// Includes all the files related to pcie_phy rc
//--------------------------------------------------------------------------------------------
package pcie_phy_rc_pkg;

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
  `include "pcie_phy_rc_agent_config.sv"
  `include "pcie_phy_rc_tx.sv"
  `include "pcie_phy_rc_seq_item_converter.sv"
  `include "pcie_phy_rc_cfg_converter.sv"
  `include "pcie_phy_rc_ltssm_sequencer.sv"
  `include "pcie_phy_rc_driver_proxy.sv"
  `include "pcie_phy_rc_monitor_proxy.sv"
  `include "pcie_phy_rc_coverage.sv"
  `include "pcie_phy_rc_agent.sv"

endpackage : pcie_phy_rc_pkg

`endif
