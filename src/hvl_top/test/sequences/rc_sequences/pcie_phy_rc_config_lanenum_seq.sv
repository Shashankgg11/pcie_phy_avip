`ifndef PCIE_PHY_RC_CONFIG_LANENUM_SEQ_INCLUDED_
`define PCIE_PHY_RC_CONFIG_LANENUM_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_config_lanenum_seq
// Config Lanenum Seq for the Downstream Port (Root Complex)
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_config_lanenum_seq extends uvm_sequence #(pcie_phy_rc_tx);
  `uvm_object_utils(pcie_phy_rc_config_lanenum_seq)

  pcie_phy_rc_tx req;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_config_lanenum_seq");
  extern task body();

endclass : pcie_phy_rc_config_lanenum_seq

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes the sequence object
//
// Parameters:
//  name - pcie_phy_rc_config_lanenum_seq
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_config_lanenum_seq::new(string name = "pcie_phy_rc_config_lanenum_seq");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: body
// Drives the config_lanenum_seq directive to the rc LTSSM
//--------------------------------------------------------------------------------------------
task pcie_phy_rc_config_lanenum_seq::body();
  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)
  req = pcie_phy_rc_tx::type_id::create("req");
  start_item(req);
  if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
  // TODO: constrain req.target_state / directive fields for this sequence
  finish_item(req);
endtask : body


`endif
