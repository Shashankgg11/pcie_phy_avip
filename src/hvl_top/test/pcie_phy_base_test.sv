`ifndef PCIE_PHY_BASE_TEST_INCLUDED_
`define PCIE_PHY_BASE_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_base_test
// Base test has the test scenarios for the testbench which has the env, config, etc. Sequences are created and started in the test
//--------------------------------------------------------------------------------------------
class pcie_phy_base_test extends uvm_test;
  `uvm_component_utils(pcie_phy_base_test)

  //Variable: pcie_phy_env_cfg_h
  pcie_phy_env_config pcie_phy_env_cfg_h;

  //Variable: pcie_phy_env_h
  pcie_phy_env pcie_phy_env_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_base_test", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void setup_pcie_phy_env_cfg();
  extern virtual function void setup_pcie_phy_rc_agent_cfg();
  extern virtual function void setup_pcie_phy_ep_agent_cfg();
  extern virtual function void end_of_elaboration_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_base_test

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_base_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_base_test::new(string name = "pcie_phy_base_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// Create required ports
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_base_test::build_phase(uvm_phase phase);
  super.build_phase(phase);
  setup_pcie_phy_env_cfg();
  pcie_phy_env_h = pcie_phy_env::type_id::create("pcie_phy_env_h", this);
  uvm_config_db#(pcie_phy_env_config)::set(this, "*", "pcie_phy_env_config", pcie_phy_env_cfg_h);
  setup_pcie_phy_rc_agent_cfg();
  setup_pcie_phy_ep_agent_cfg();
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: setup_pcie_phy_env_cfg
// <Description_here>
//--------------------------------------------------------------------------------------------
function void pcie_phy_base_test::setup_pcie_phy_env_cfg();
  pcie_phy_env_cfg_h = pcie_phy_env_config::type_id::create("pcie_phy_env_cfg_h");
endfunction : setup_pcie_phy_env_cfg

//--------------------------------------------------------------------------------------------
// Function: setup_pcie_phy_rc_agent_cfg
// <Description_here>
//--------------------------------------------------------------------------------------------
function void pcie_phy_base_test::setup_pcie_phy_rc_agent_cfg();
  // TODO: create + randomize pcie_phy_rc_agent_config, set into env_cfg_h array
endfunction : setup_pcie_phy_rc_agent_cfg

//--------------------------------------------------------------------------------------------
// Function: setup_pcie_phy_ep_agent_cfg
// <Description_here>
//--------------------------------------------------------------------------------------------
function void pcie_phy_base_test::setup_pcie_phy_ep_agent_cfg();
  // TODO: create + randomize pcie_phy_ep_agent_config, set into env_cfg_h array
endfunction : setup_pcie_phy_ep_agent_cfg

//--------------------------------------------------------------------------------------------
// Function: end_of_elaboration_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_base_test::end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
endfunction : end_of_elaboration_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_base_test::run_phase(uvm_phase phase);
  // Work here
  // ...
endtask : run_phase


`endif
