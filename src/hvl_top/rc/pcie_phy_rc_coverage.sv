`ifndef PCIE_PHY_RC_COVERAGE_INCLUDED_
`define PCIE_PHY_RC_COVERAGE_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_coverage
// Functional coverage for the Downstream Port (Root Complex) LTSSM
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_coverage extends uvm_subscriber #(pcie_phy_rc_tx);
  `uvm_component_utils(pcie_phy_rc_coverage)

  //Variable: pcie_phy_rc_agent_cfg_h
  pcie_phy_rc_agent_config pcie_phy_rc_agent_cfg_h;

  //Variable: analysis_export
  uvm_analysis_imp #(pcie_phy_rc_tx, pcie_phy_rc_coverage) analysis_export;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_coverage", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual function void write(pcie_phy_rc_tx t);

endclass : pcie_phy_rc_coverage

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_rc_coverage
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_coverage::new(string name = "pcie_phy_rc_coverage", uvm_component parent = null);
  super.new(name, parent);
  analysis_export = new("analysis_export", this);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_coverage::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_coverage::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Function: write
// <Description_here> — sample covergroups from t
//
// Parameters:
//  t - transaction sampled from monitor_proxy analysis port
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_coverage::write(pcie_phy_rc_tx t);
  // TODO: cg.sample() calls per LTSSM state / rate / directive
endfunction : write


`endif
