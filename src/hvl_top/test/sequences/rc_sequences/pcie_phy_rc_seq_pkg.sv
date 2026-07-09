`ifndef PCIE_PHY_RC_SEQ_PKG_INCLUDED_
`define PCIE_PHY_RC_SEQ_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package: pcie_phy_rc_seq_pkg
// Includes all rc state sequences
//--------------------------------------------------------------------------------------------
package pcie_phy_rc_seq_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import pcie_phy_globals_pkg::*;
  import pcie_phy_rc_pkg::*;

  `include "pcie_phy_rc_detect_seq.sv"
  `include "pcie_phy_rc_polling_active_seq.sv"
  `include "pcie_phy_rc_polling_compliance_seq.sv"
  `include "pcie_phy_rc_polling_configuration_seq.sv"
  `include "pcie_phy_rc_config_linkwidth_seq.sv"
  `include "pcie_phy_rc_config_lanenum_seq.sv"
  `include "pcie_phy_rc_config_complete_seq.sv"
  `include "pcie_phy_rc_recovery_rcvrlock_seq.sv"
  `include "pcie_phy_rc_recovery_equalization_seq.sv"
  `include "pcie_phy_rc_recovery_speed_seq.sv"
  `include "pcie_phy_rc_recovery_rcvrcfg_seq.sv"
  `include "pcie_phy_rc_l0_seq.sv"
  `include "pcie_phy_rc_l0p_seq.sv"
  `include "pcie_phy_rc_l0s_seq.sv"
  `include "pcie_phy_rc_l1_seq.sv"

endpackage : pcie_phy_rc_seq_pkg

`endif
