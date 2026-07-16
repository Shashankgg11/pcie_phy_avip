`ifndef PCIE_PHY_SMOKE_TEST_INCLUDED_
`define PCIE_PHY_SMOKE_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_smoke_test
// Minimal smoke test — only test needed to validate the compile/elaborate/simulate flow.
// Run it directly with: make run TESTNAME=pcie_phy_smoke_test (questasim/Makefile default)
//--------------------------------------------------------------------------------------------
class pcie_phy_smoke_test extends pcie_phy_base_test;
  `uvm_component_utils(pcie_phy_smoke_test)

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_smoke_test", uvm_component parent = null);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_smoke_test

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_smoke_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_smoke_test::new(string name = "pcie_phy_smoke_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: run_phase
// Minimal run_phase — no sequences are started. Just proves the environment, driver_bfm and monitor_bfm are up and simulating cleanly.
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_smoke_test::run_phase(uvm_phase phase);
  phase.raise_objection(this);

  `uvm_info(get_type_name(), "pcie_phy_smoke_test : run_phase started", UVM_LOW)
  #100ns;
  `uvm_info(get_type_name(), "pcie_phy_smoke_test : LTSSM BFMs are up, no stimulus driven (smoke test)", UVM_LOW)
  #100ns;
  `uvm_info(get_type_name(), "pcie_phy_smoke_test : run_phase completed successfully", UVM_LOW)

  phase.drop_objection(this);
endtask : run_phase


`endif
