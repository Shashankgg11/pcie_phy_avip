`ifndef PCIE_PHY_RC_LTSSM_SEQUENCER_INCLUDED_
`define PCIE_PHY_RC_LTSSM_SEQUENCER_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_ltssm_sequencer
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_ltssm_sequencer extends uvm_sequencer#(pcie_phy_rc_tx);
  `uvm_component_utils(pcie_phy_rc_ltssm_sequencer)

  //Variable: pcie_phy_rc_agent_cfg_h
  pcie_phy_rc_agent_config pcie_phy_rc_agent_cfg_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_ltssm_sequencer", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_rc_ltssm_sequencer

//--------------------------------------------------------------------------------------------
// Construct: new
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_ltssm_sequencer::new(string name = "pcie_phy_rc_ltssm_sequencer", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_ltssm_sequencer::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_ltssm_sequencer::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
//--------------------------------------------------------------------------------------------
task pcie_phy_rc_ltssm_sequencer::run_phase(uvm_phase phase);

  // Work here
  // ...

endtask : run_phase


`endif
