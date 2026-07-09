`ifndef PCIE_PHY_EP_LTSSM_SEQUENCER_INCLUDED_
`define PCIE_PHY_EP_LTSSM_SEQUENCER_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_ltssm_sequencer
// LTSSM sequencer for the Upstream Port (Endpoint)
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_ltssm_sequencer extends uvm_sequencer#(pcie_phy_ep_tx);
  `uvm_component_utils(pcie_phy_ep_ltssm_sequencer)

  //Variable: pcie_phy_ep_agent_cfg_h
  pcie_phy_ep_agent_config pcie_phy_ep_agent_cfg_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_ep_ltssm_sequencer", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_ep_ltssm_sequencer

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_ep_ltssm_sequencer
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_ep_ltssm_sequencer::new(string name = "pcie_phy_ep_ltssm_sequencer", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_ltssm_sequencer::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_ltssm_sequencer::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_ep_ltssm_sequencer::run_phase(uvm_phase phase);

  // Work here
  // ...

endtask : run_phase


`endif
