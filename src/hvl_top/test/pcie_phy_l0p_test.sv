`ifndef PCIE_PHY_L0P_TEST_INCLUDED_
`define PCIE_PHY_L0P_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_l0p_test
// Test: pcie_phy_l0p_test
//--------------------------------------------------------------------------------------------
class pcie_phy_l0p_test extends pcie_phy_base_test;
  `uvm_component_utils(pcie_phy_l0p_test)

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_l0p_test", uvm_component parent = null);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_l0p_test

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_l0p_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_l0p_test::new(string name = "pcie_phy_l0p_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: run_phase
// Creates and starts the l0p test virtual sequence
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_l0p_test::run_phase(uvm_phase phase);
  // TODO: create the matching pcie_phy_virtual_*_seq, raise/drop objection, start on
  //       pcie_phy_env_h.pcie_phy_virtual_seqr_h
  phase.raise_objection(this);
  // vseq_h.start(pcie_phy_env_h.pcie_phy_virtual_seqr_h);
  phase.drop_objection(this);
endtask : run_phase


`endif
