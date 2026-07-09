`ifndef PCIE_PHY_VIRTUAL_SEQUENCER_INCLUDED_
`define PCIE_PHY_VIRTUAL_SEQUENCER_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_virtual_sequencer
// This class contains the handles of the actual sequencers pointing towards them
//--------------------------------------------------------------------------------------------
class pcie_phy_virtual_sequencer extends uvm_sequencer#(uvm_sequence_item);
  `uvm_component_utils(pcie_phy_virtual_sequencer)

  //Variable: pcie_phy_rc_ltssm_seqr_h
  pcie_phy_rc_ltssm_sequencer pcie_phy_rc_ltssm_seqr_h;

  //Variable: pcie_phy_ep_ltssm_seqr_h
  pcie_phy_ep_ltssm_sequencer pcie_phy_ep_ltssm_seqr_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_virtual_sequencer", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_virtual_sequencer

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_virtual_sequencer
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_virtual_sequencer::new(string name = "pcie_phy_virtual_sequencer", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_virtual_sequencer::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_virtual_sequencer::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_virtual_sequencer::run_phase(uvm_phase phase);

  // Work here
  // ...

endtask : run_phase


`endif
