`ifndef PCIE_PHY_VIRTUAL_SEQ_PKG_INCLUDED_
`define PCIE_PHY_VIRTUAL_SEQ_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package: pcie_phy_virtual_seq_pkg
// Includes all virtual sequences
//--------------------------------------------------------------------------------------------
package pcie_phy_virtual_seq_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import pcie_phy_globals_pkg::*;
  import pcie_phy_rc_pkg::*;
  import pcie_phy_ep_pkg::*;
  import pcie_phy_rc_seq_pkg::*;
  import pcie_phy_ep_seq_pkg::*;
  import pcie_phy_env_pkg::*;

  `include "pcie_phy_virtual_base_seq.sv"
  `include "pcie_phy_virtual_link_training_seq.sv"
  `include "pcie_phy_virtual_equalization_8gt_seq.sv"
  `include "pcie_phy_virtual_equalization_16gt_seq.sv"
  `include "pcie_phy_virtual_equalization_32gt_seq.sv"
  `include "pcie_phy_virtual_equalization_64gt_seq.sv"
  `include "pcie_phy_virtual_l0p_seq.sv"
  `include "pcie_phy_virtual_sris_seq.sv"
  `include "pcie_phy_virtual_speed_change_seq.sv"
  `include "pcie_phy_virtual_width_change_seq.sv"
  `include "pcie_phy_virtual_error_injection_timeout_seq.sv"
  `include "pcie_phy_virtual_error_injection_eq_reject_seq.sv"
  `include "pcie_phy_virtual_error_injection_illegal_ts_seq.sv"
  `include "pcie_phy_virtual_hot_reset_seq.sv"
  `include "pcie_phy_virtual_loopback_seq.sv"
  `include "pcie_phy_virtual_disable_link_seq.sv"
  `include "pcie_phy_virtual_crosslink_seq.sv"
  `include "pcie_phy_virtual_full_regression_seq.sv"

endpackage : pcie_phy_virtual_seq_pkg

`endif
