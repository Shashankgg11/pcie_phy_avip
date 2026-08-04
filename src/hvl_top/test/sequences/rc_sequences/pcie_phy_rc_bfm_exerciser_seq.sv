`ifndef PCIE_PHY_RC_BFM_EXERCISER_SEQ_INCLUDED_
`define PCIE_PHY_RC_BFM_EXERCISER_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_bfm_exerciser_seq
// Test/debug-only sequence - has no protocol meaning. Sends one is_bfm_verify_item per
// currently-implemented rc_driver_bfm task so every one of them gets called at least once:
//   VERIFY_SEND_TS1  -> drive_ts(OS_TS1, ...)  (also exercises build_ts_bytes,
//                                                encode_8b10b_symbol, next_running_disparity)
//   VERIFY_SEND_TS2  -> drive_ts(OS_TS2, ...)  (same internals, different ID byte)
//   VERIFY_SEND_IDLE -> drive_idle()
// wait_for_reset()/default_values() are already exercised automatically by
// pcie_phy_rc_driver_proxy::run_phase() at startup, so they aren't repeated here.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_bfm_exerciser_seq extends uvm_sequence #(pcie_phy_rc_tx);
  `uvm_object_utils(pcie_phy_rc_bfm_exerciser_seq)

  pcie_phy_rc_tx req;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_bfm_exerciser_seq");
  extern task body();
  extern task send_task(bfm_verify_task_e t);

endclass : pcie_phy_rc_bfm_exerciser_seq

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes the sequence object
//
// Parameters:
//  name - pcie_phy_rc_bfm_exerciser_seq
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_bfm_exerciser_seq::new(string name = "pcie_phy_rc_bfm_exerciser_seq");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Task: send_task
// Builds and sends one is_bfm_verify_item requesting the given task.
//
// Parameters:
//  t - which driver_bfm task to exercise
//--------------------------------------------------------------------------------------------
task pcie_phy_rc_bfm_exerciser_seq::send_task(bfm_verify_task_e t);
  req = pcie_phy_rc_tx::type_id::create("req");
  start_item(req);
  if (!req.randomize())
    `uvm_error(get_type_name(), "Randomization failed")
  //is_bfm_verify_item/requested_task are plain (non-rand) directive fields - set them
  //directly after randomize() rather than via a randomize()-with constraint.
  req.is_bfm_verify_item = 1;
  req.requested_task     = t;
  finish_item(req);
endtask : send_task

//--------------------------------------------------------------------------------------------
// Task: body
// Walks every rc driver_bfm task once, back to back.
//--------------------------------------------------------------------------------------------
task pcie_phy_rc_bfm_exerciser_seq::body();
  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  send_task(VERIFY_SEND_TS1);
  send_task(VERIFY_SEND_TS2);
  send_task(VERIFY_SEND_IDLE);

  send_task(VERIFY_CHECK_ELECTRICAL_IDLE_EXIT);
  send_task(VERIFY_PERFORM_RECEIVER_DETECTION);
  send_task(VERIFY_RUN_DETECT_QUIET);
  send_task(VERIFY_RUN_DETECT_ACTIVE);

  send_task(VERIFY_RUN_POLLING);

  // Configuration State
  send_task(VERIFY_RUN_CONFIG_LINKWIDTH_START);
  send_task(VERIFY_RUN_CONFIG_LINKWIDTH_ACCEPT);
  send_task(VERIFY_RUN_CONFIG_LANENUM_WAIT);

  `uvm_info(get_type_name(), $sformatf("%s : all rc driver_bfm tasks exercised", get_type_name()), UVM_MEDIUM)
endtask : body

`endif
