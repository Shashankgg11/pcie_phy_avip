`ifndef PCIE_PHY_VIRTUAL_LINK_TRAINING_SEQ_INCLUDED_
`define PCIE_PHY_VIRTUAL_LINK_TRAINING_SEQ_INCLUDED_


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



endtask : body

`endif
