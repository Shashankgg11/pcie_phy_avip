`ifndef ASSERTION_BASE_TEST_INCLUDED_
`define ASSERTION_BASE_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: assertion_base_test
// Base test variant that additionally binds/enables SVA assertion checkers
//--------------------------------------------------------------------------------------------
class assertion_base_test extends pcie_phy_base_test;
  `uvm_component_utils(assertion_base_test)

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "assertion_base_test", uvm_component parent = null);

endclass : assertion_base_test

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - assertion_base_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function assertion_base_test::new(string name = "assertion_base_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new


`endif
