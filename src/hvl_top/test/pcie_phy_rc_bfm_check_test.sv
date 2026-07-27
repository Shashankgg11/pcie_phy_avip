`ifndef PCIE_PHY_RC_BFM_CHECK_TEST_INCLUDED_
`define PCIE_PHY_RC_BFM_CHECK_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_bfm_check_test
// Directed BFM sanity test - starts pcie_phy_rc_detect_seq (drives one TS1 via drive_ts) then
// pcie_phy_rc_l0_seq (drives Idle via drive_idle) straight on the rc sequencer, bypassing the
// virtual-sequence layer entirely. Intended to be run with waveforms on and inspected by hand:
// see the "Verifying a driver_bfm task" writeup for what to look at and how to extend this to
// a new state/task.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_bfm_check_test extends pcie_phy_base_test;
  `uvm_component_utils(pcie_phy_rc_bfm_check_test)

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_bfm_check_test", uvm_component parent = null);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_rc_bfm_check_test

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_rc_bfm_check_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_bfm_check_test::new(string name = "pcie_phy_rc_bfm_check_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: run_phase
// Runs detect_seq (TS1 via drive_ts) then l0_seq (Idle via drive_idle) directly on the RC
// LTSSM sequencer - one item each, back to back, with a settle gap in between so the two
// bursts are easy to tell apart on the waveform.
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_rc_bfm_check_test::run_phase(uvm_phase phase);
  pcie_phy_rc_detect_seq detect_seq_h;
  pcie_phy_rc_l0_seq     l0_seq_h;

  phase.raise_objection(this);

  `uvm_info(get_type_name(), "pcie_phy_rc_bfm_check_test : starting detect_seq (TS1 / drive_ts)", UVM_LOW)
  detect_seq_h = pcie_phy_rc_detect_seq::type_id::create("detect_seq_h");
  detect_seq_h.start(pcie_phy_env_h.pcie_phy_rc_agent_h[0].pcie_phy_rc_ltssm_seqr_h);

  #200ns;

  `uvm_info(get_type_name(), "pcie_phy_rc_bfm_check_test : starting l0_seq (Idle / drive_idle)", UVM_LOW)
  l0_seq_h = pcie_phy_rc_l0_seq::type_id::create("l0_seq_h");
  l0_seq_h.start(pcie_phy_env_h.pcie_phy_rc_agent_h[0].pcie_phy_rc_ltssm_seqr_h);

  #200ns;

  `uvm_info(get_type_name(), "pcie_phy_rc_bfm_check_test : done", UVM_LOW)
  phase.drop_objection(this);
endtask : run_phase

`endif
