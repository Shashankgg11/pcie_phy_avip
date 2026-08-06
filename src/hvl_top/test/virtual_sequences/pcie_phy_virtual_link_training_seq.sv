`ifndef PCIE_PHY_VIRTUAL_LINK_TRAINING_SEQ_INCLUDED_
`define PCIE_PHY_VIRTUAL_LINK_TRAINING_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_virtual_link_training_seq
// Creates and starts the rc/ep state sequences for this scenario. RC and EP sequences run
// CONCURRENTLY (fork/join) at every step - not sequentially - because the protocol is
// inherently bidirectional: RC's run_polling_active() cannot see a matching TS1 unless EP is
// simultaneously running its own run_polling_active() and actually sending one back. Running
// them one after another would deadlock (RC waits, but EP never runs to respond).
//
// Currently covers Detect -> Polling. Configuration/Recovery follow the exact same pattern -
// see the note at the end of body() for how to extend it once the remaining per-state
// sequences (pcie_phy_rc/ep_config_linkwidth_seq, _lanenum_seq, _complete_seq, recovery_*)
// are filled in the same way pcie_phy_rc_detect_seq/pcie_phy_rc_polling_active_seq were.
//--------------------------------------------------------------------------------------------
class pcie_phy_virtual_link_training_seq extends pcie_phy_virtual_base_seq;
  `uvm_object_utils(pcie_phy_virtual_link_training_seq)

  extern function new(string name = "pcie_phy_virtual_link_training_seq");
  extern virtual task body();

endclass : pcie_phy_virtual_link_training_seq

function pcie_phy_virtual_link_training_seq::new(string name = "pcie_phy_virtual_link_training_seq");
  super.new(name);
endfunction : new

task pcie_phy_virtual_link_training_seq::body();
  pcie_phy_rc_detect_seq         rc_detect;
  pcie_phy_ep_detect_seq         ep_detect;
  pcie_phy_rc_polling_active_seq rc_poll_active;
  pcie_phy_ep_polling_active_seq ep_poll_active;

  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  //-------------------------------------------------------
  // Detect - both sides concurrently, each internally retries Quiet<->Active until it
  // genuinely reaches POLLING_ST or gives up.
  //-------------------------------------------------------
  rc_detect = pcie_phy_rc_detect_seq::type_id::create("rc_detect");
  ep_detect = pcie_phy_ep_detect_seq::type_id::create("ep_detect");
  fork
    rc_detect.start(p_sequencer.pcie_phy_rc_ltssm_seqr_h);
    ep_detect.start(p_sequencer.pcie_phy_ep_ltssm_seqr_h);
  join

  if (rc_detect.final_state != POLLING_ST || ep_detect.final_state != POLLING_ST) begin
    `uvm_error(get_type_name(), "Detect failed on at least one side - stopping training")
    return;
  end

  //-------------------------------------------------------
  // Polling.Active - both sides concurrently, same reasoning
  //-------------------------------------------------------
  rc_poll_active = pcie_phy_rc_polling_active_seq::type_id::create("rc_poll_active");
  ep_poll_active = pcie_phy_ep_polling_active_seq::type_id::create("ep_poll_active");
  fork
    rc_poll_active.start(p_sequencer.pcie_phy_rc_ltssm_seqr_h);
    ep_poll_active.start(p_sequencer.pcie_phy_ep_ltssm_seqr_h);
  join

  if (rc_poll_active.final_state == DETECT_ST || ep_poll_active.final_state == DETECT_ST) begin
    `uvm_error(get_type_name(), "Polling.Active timed out on at least one side - stopping training")
    return;
  end

  `uvm_info(get_type_name(),
            $sformatf("Reached Polling.%s on RC, Polling.%s on EP",
                      rc_poll_active.final_polling_substate.name(),
                      ep_poll_active.final_polling_substate.name()),
            UVM_LOW)

  //-------------------------------------------------------
  // TODO: Configuration and Recovery follow the exact same fork/join pattern:
  //   1. Fill in pcie_phy_rc/ep_config_linkwidth_seq, _lanenum_seq, _complete_seq
  //      (and recovery_rcvrlock/speed/rcvrcfg/equalization_seq for speed steps above GEN1)
  //      the same way pcie_phy_rc_detect_seq and pcie_phy_rc_polling_active_seq were done:
  //      set req.task_id to the matching LTSSM_TASK_* value, finish_item(), read back
  //      req.rsp_state/rsp_config_substate onto a final_state/final_config_substate field.
  //   2. Add the matching fork/join block here, checking final_state after each step
  //      exactly like the two blocks above.
  //-------------------------------------------------------

endtask : body

`endif
