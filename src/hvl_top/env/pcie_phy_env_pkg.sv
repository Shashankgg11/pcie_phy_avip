`ifndef PCIE_PHY_ENV_PKG_INCLUDED_
`define PCIE_PHY_ENV_PKG_INCLUDED_

// --------------------------------------------------------------------------------------------
// Package: pcie_phy_env_pkg
// Includes all the files related to the pcie_phy env
//--------------------------------------------------------------------------------------------
package pcie_phy_env_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;

  import pcie_phy_globals_pkg::*;
  import pcie_phy_rc_pkg::*;
  import pcie_phy_ep_pkg::*;

  `include "pcie_phy_env_config.sv"
  `include "virtual_sequencer/pcie_phy_virtual_sequencer.sv"
  `include "pcie_phy_scoreboard.sv"
  `include "pcie_phy_env.sv"

endpackage : pcie_phy_env_pkg

`endif
