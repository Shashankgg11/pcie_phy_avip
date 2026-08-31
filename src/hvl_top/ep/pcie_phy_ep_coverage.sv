`ifndef PCIE_PHY_EP_COVERAGE_INCLUDED_
`define PCIE_PHY_EP_COVERAGE_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_coverage
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_coverage extends uvm_subscriber #(pcie_phy_ep_tx);
  `uvm_component_utils(pcie_phy_ep_coverage)

  //Variable: pcie_phy_ep_agent_cfg_h
  pcie_phy_ep_agent_config pcie_phy_ep_agent_cfg_h;

  //Variable: analysis_export
  uvm_analysis_imp #(pcie_phy_ep_tx, pcie_phy_ep_coverage) analysis_export;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_ep_coverage", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual function void write(pcie_phy_ep_tx t);

endclass : pcie_phy_ep_coverage

//--------------------------------------------------------------------------------------------
// Construct: new
//--------------------------------------------------------------------------------------------
function pcie_phy_ep_coverage::new(string name = "pcie_phy_ep_coverage", uvm_component parent = null);
  super.new(name, parent);
  analysis_export = new("analysis_export", this);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_coverage::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_coverage::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Function: write
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_coverage::write(pcie_phy_ep_tx t);
  // TODO: cg.sample() calls per LTSSM state
endfunction : write


`endif
