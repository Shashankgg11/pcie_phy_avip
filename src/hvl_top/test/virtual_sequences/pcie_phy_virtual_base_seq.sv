`ifndef PCIE_PHY_VIRTUAL_BASE_SEQ_INCLUDED_
`define PCIE_PHY_VIRTUAL_BASE_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_virtual_base_seq
// This class contains the handle of the actual sequencers pointing towards them
//--------------------------------------------------------------------------------------------
class pcie_phy_virtual_base_seq extends uvm_sequence;
  `uvm_object_utils(pcie_phy_virtual_base_seq)

  //p_sequencer macro declaration
  `uvm_declare_p_sequencer(pcie_phy_virtual_sequencer)

  pcie_phy_env_config env_cfg_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_virtual_base_seq");
  extern virtual task body();

endclass : pcie_phy_virtual_base_seq

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes new memory for the object
//
// Parameters:
//  name - instance name of the virtual_sequence
//--------------------------------------------------------------------------------------------
function pcie_phy_virtual_base_seq::new(string name = "pcie_phy_virtual_base_seq");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: body
// Fetches env_cfg and casts p_sequencer
//--------------------------------------------------------------------------------------------
task pcie_phy_virtual_base_seq::body();
  if (!uvm_config_db#(pcie_phy_env_config)::get(null, get_full_name(), "pcie_phy_env_config", env_cfg_h)) begin
    `uvm_fatal("CONFIG", "cannot get() env_cfg from uvm_config_db. Have you set() it?")
  end

  if (!$cast(p_sequencer, m_sequencer)) begin
    `uvm_error(get_full_name(), "Virtual sequencer pointer cast failed")
  end
endtask : body


`endif
