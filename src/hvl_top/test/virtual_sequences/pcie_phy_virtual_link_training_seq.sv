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

  //-------------------------------------------------------
  // Polling.Configuration - both sides concurrently
  //-------------------------------------------------------
  begin
    pcie_phy_rc_polling_configuration_seq rc_poll_cfg;
    pcie_phy_ep_polling_configuration_seq ep_poll_cfg;

    rc_poll_cfg = pcie_phy_rc_polling_configuration_seq::type_id::create("rc_poll_cfg");
    ep_poll_cfg = pcie_phy_ep_polling_configuration_seq::type_id::create("ep_poll_cfg");
    fork
      rc_poll_cfg.start(p_sequencer.pcie_phy_rc_ltssm_seqr_h);
      ep_poll_cfg.start(p_sequencer.pcie_phy_ep_ltssm_seqr_h);
    join

    if (rc_poll_cfg.final_state == DETECT_ST || ep_poll_cfg.final_state == DETECT_ST) begin
      `uvm_error(get_type_name(), "Polling.Configuration failed on at least one side - stopping training")
      return;
    end
  end

  //-------------------------------------------------------
  // Configuration.Linkwidth - both sides concurrently
  //-------------------------------------------------------
  begin
    pcie_phy_rc_config_linkwidth_seq rc_cfg_lw;
    pcie_phy_ep_config_linkwidth_seq ep_cfg_lw;

    rc_cfg_lw = pcie_phy_rc_config_linkwidth_seq::type_id::create("rc_cfg_lw");
    ep_cfg_lw = pcie_phy_ep_config_linkwidth_seq::type_id::create("ep_cfg_lw");
    fork
      rc_cfg_lw.start(p_sequencer.pcie_phy_rc_ltssm_seqr_h);
      ep_cfg_lw.start(p_sequencer.pcie_phy_ep_ltssm_seqr_h);
    join

    if (rc_cfg_lw.final_state == DETECT_ST || ep_cfg_lw.final_state == DETECT_ST) begin
      `uvm_error(get_type_name(), "Configuration.Linkwidth failed on at least one side - stopping training")
      return;
    end
  end

  //-------------------------------------------------------
  // Configuration.Lanenum - both sides concurrently
  //-------------------------------------------------------
  begin
    pcie_phy_rc_config_lanenum_seq rc_cfg_ln;
    pcie_phy_ep_config_lanenum_seq ep_cfg_ln;

    rc_cfg_ln = pcie_phy_rc_config_lanenum_seq::type_id::create("rc_cfg_ln");
    ep_cfg_ln = pcie_phy_ep_config_lanenum_seq::type_id::create("ep_cfg_ln");
    fork
      rc_cfg_ln.start(p_sequencer.pcie_phy_rc_ltssm_seqr_h);
      ep_cfg_ln.start(p_sequencer.pcie_phy_ep_ltssm_seqr_h);
    join

    if (rc_cfg_ln.final_state == DETECT_ST || ep_cfg_ln.final_state == DETECT_ST) begin
      `uvm_error(get_type_name(), "Configuration.Lanenum failed on at least one side - stopping training")
      return;
    end
  end

  //-------------------------------------------------------
  // Configuration.Complete + Idle - both sides concurrently, ends at L0_ST
  //-------------------------------------------------------
  begin
    pcie_phy_rc_config_complete_seq rc_cfg_complete;
    pcie_phy_ep_config_complete_seq ep_cfg_complete;

    rc_cfg_complete = pcie_phy_rc_config_complete_seq::type_id::create("rc_cfg_complete");
    ep_cfg_complete = pcie_phy_ep_config_complete_seq::type_id::create("ep_cfg_complete");
    fork
      rc_cfg_complete.start(p_sequencer.pcie_phy_rc_ltssm_seqr_h);
      ep_cfg_complete.start(p_sequencer.pcie_phy_ep_ltssm_seqr_h);
    join

    if (rc_cfg_complete.final_state != L0_ST || ep_cfg_complete.final_state != L0_ST) begin
      `uvm_error(get_type_name(), "Configuration.Complete/Idle failed on at least one side - stopping training")
      return;
    end
  end

  //-------------------------------------------------------
  // L0 - both sides concurrently. run_l0() runs indefinitely during healthy operation, so
  // both l0_seqs are started fire-and-forget (join_none) rather than waited on - reaching
  // this point with both sides confirming rsp_state=L0_ST IS the definition of successful
  // training completion for this sequence.
  //-------------------------------------------------------
  begin
    pcie_phy_rc_l0_seq rc_l0;
    pcie_phy_ep_l0_seq ep_l0;

    rc_l0 = pcie_phy_rc_l0_seq::type_id::create("rc_l0");
    ep_l0 = pcie_phy_ep_l0_seq::type_id::create("ep_l0");
    fork
      rc_l0.start(p_sequencer.pcie_phy_rc_ltssm_seqr_h);
      ep_l0.start(p_sequencer.pcie_phy_ep_ltssm_seqr_h);
    join

    if (rc_l0.final_state == L0_ST && ep_l0.final_state == L0_ST) begin
      `uvm_info(get_type_name(), "TRAINING COMPLETE - both RC and EP reached L0", UVM_LOW)
    end
    else begin
      `uvm_error(get_type_name(), "L0 entry failed on at least one side")
    end
  end

endtask : body

`endif
