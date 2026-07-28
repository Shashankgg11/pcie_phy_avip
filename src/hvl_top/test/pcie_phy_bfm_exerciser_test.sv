`ifndef PCIE_PHY_BFM_EXERCISER_TEST_INCLUDED_
`define PCIE_PHY_BFM_EXERCISER_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_bfm_exerciser_test
// Test/debug-only test - has no protocol meaning. Starts pcie_phy_rc_bfm_exerciser_seq on
// the RC sequencer and pcie_phy_ep_bfm_exerciser_seq on the EP sequencer (fork/join, so both
// sides run in parallel), exercising every currently-implemented task in both rc_driver_bfm
// and ep_driver_bfm at least once. Nothing in either driver_bfm was modified to support this -
// only the dispatch in rc_driver_proxy/ep_driver_proxy was extended with an additional
// is_bfm_verify_item path, kept fully separate from the normal target_state path.
//
// Run with:
//   make simulate TESTNAME=pcie_phy_bfm_exerciser_test
//--------------------------------------------------------------------------------------------
class pcie_phy_bfm_exerciser_test extends pcie_phy_base_test;
  `uvm_component_utils(pcie_phy_bfm_exerciser_test)

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_bfm_exerciser_test", uvm_component parent = null);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_bfm_exerciser_test

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_bfm_exerciser_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_bfm_exerciser_test::new(string name = "pcie_phy_bfm_exerciser_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: run_phase
// Runs the rc and ep BFM-exerciser sequences in parallel, each walking every task on its
// respective driver_bfm once.
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_bfm_exerciser_test::run_phase(uvm_phase phase);
  pcie_phy_rc_bfm_exerciser_seq rc_seq_h;
  pcie_phy_ep_bfm_exerciser_seq ep_seq_h;

  phase.raise_objection(this);

  `uvm_info(get_type_name(), "pcie_phy_bfm_exerciser_test : exercising every rc + ep driver_bfm task", UVM_LOW)

  rc_seq_h = pcie_phy_rc_bfm_exerciser_seq::type_id::create("rc_seq_h");
  ep_seq_h = pcie_phy_ep_bfm_exerciser_seq::type_id::create("ep_seq_h");

  fork
    rc_seq_h.start(pcie_phy_env_h.pcie_phy_rc_agent_h[0].pcie_phy_rc_ltssm_seqr_h);
    ep_seq_h.start(pcie_phy_env_h.pcie_phy_ep_agent_h[0].pcie_phy_ep_ltssm_seqr_h);
  join

  #200ns;

  `uvm_info(get_type_name(), "pcie_phy_bfm_exerciser_test : done", UVM_LOW)
  phase.drop_objection(this);
endtask : run_phase

`endif
