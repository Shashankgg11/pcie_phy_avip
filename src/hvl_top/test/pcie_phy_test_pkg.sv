`ifndef PCIE_PHY_TEST_PKG_INCLUDED_
`define PCIE_PHY_TEST_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package: pcie_phy_test_pkg
// Includes all the files written to run the simulation
//--------------------------------------------------------------------------------------------
package pcie_phy_test_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import pcie_phy_globals_pkg::*;
  import pcie_phy_rc_pkg::*;
  import pcie_phy_ep_pkg::*;
  import pcie_phy_env_pkg::*;
  import pcie_phy_rc_seq_pkg::*;
  import pcie_phy_ep_seq_pkg::*;
  import pcie_phy_virtual_seq_pkg::*;

  `include "pcie_phy_base_test.sv"
  `include "assertion_base_test.sv"
  `include "pcie_phy_link_training_test.sv"
  `include "pcie_phy_equalization_test.sv"
  `include "pcie_phy_l0p_test.sv"
  `include "pcie_phy_sris_test.sv"
  `include "pcie_phy_error_injection_test.sv"
  `include "pcie_phy_hot_reset_test.sv"
  `include "pcie_phy_loopback_test.sv"

endpackage : pcie_phy_test_pkg

`endif
