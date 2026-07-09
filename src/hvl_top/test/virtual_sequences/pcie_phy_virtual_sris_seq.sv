`ifndef PCIE_PHY_VIRTUAL_SRIS_SEQ_INCLUDED_
`define PCIE_PHY_VIRTUAL_SRIS_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_virtual_sris_seq
// Creates and starts the rc/ep state sequences for this scenario
//--------------------------------------------------------------------------------------------
class pcie_phy_virtual_sris_seq extends pcie_phy_virtual_base_seq;
  `uvm_object_utils(pcie_phy_virtual_sris_seq)

  //Variable: state seq handles
  //Instantiation of rc/ep state sequence handles for this scenario
  // TODO: declare the specific pcie_phy_rc_*_seq / pcie_phy_ep_*_seq handles this scenario needs

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_virtual_sris_seq");
  extern virtual task body();

endclass : pcie_phy_virtual_sris_seq

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes new memory for the object
//
// Parameters:
//  name - pcie_phy_virtual_sris_seq
//--------------------------------------------------------------------------------------------
function pcie_phy_virtual_sris_seq::new(string name = "pcie_phy_virtual_sris_seq");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: body
// Creates and starts the virtual_sris_seq scenario
//--------------------------------------------------------------------------------------------
task pcie_phy_virtual_sris_seq::body();
  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  // TODO: create + start the virtual sris seq state sequences on
  //       p_sequencer.pcie_phy_rc_ltssm_seqr_h / p_sequencer.pcie_phy_ep_ltssm_seqr_h
  //       (fork/join or fork/join_none per your ordering needs)
endtask : body


`endif
