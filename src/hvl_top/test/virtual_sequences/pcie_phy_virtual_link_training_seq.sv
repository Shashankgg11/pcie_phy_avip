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

  //-------------------------------------------------------
  // Recovery - hold in L0, request Recovery, then each side runs RcvrLock -> RcvrCfg
  // on its own (PCIe 6.0 spec 4.2.7.4). The sides are NOT lock-stepped: the side that
  // finishes RcvrLock first goes straight into RcvrCfg and sends TS2, which the slower
  // side's RcvrLock accepts as its exit condition.
  //-------------------------------------------------------
  begin
    pcie_phy_rc_recovery_rcvrlock_seq rc_lock;
    pcie_phy_ep_recovery_rcvrlock_seq ep_lock;
    pcie_phy_rc_recovery_rcvrcfg_seq  rc_cfg;
    pcie_phy_ep_recovery_rcvrcfg_seq  ep_cfg;
    bit rc_lock_done;
    bit ep_lock_done;

    rc_lock = pcie_phy_rc_recovery_rcvrlock_seq::type_id::create("rc_lock");
    ep_lock = pcie_phy_ep_recovery_rcvrlock_seq::type_id::create("ep_lock");
    rc_cfg  = pcie_phy_rc_recovery_rcvrcfg_seq::type_id::create("rc_cfg");
    ep_cfg  = pcie_phy_ep_recovery_rcvrcfg_seq::type_id::create("ep_cfg");

    `uvm_info(get_type_name(), "In L0 - holding 5us, then requesting Recovery", UVM_LOW)
    #5us;

    // recovery_request is one shared flag that either run_l0 may clear, so keep
    // asserting it until both RcvrLock sequences have returned
    rc_lock_done = 1'b0;
    ep_lock_done = 1'b0;
    fork
      begin
        while (!(rc_lock_done && ep_lock_done)) begin
          pcie_phy_pkg::recovery_request = 1'b1;
          #100ns;
        end
        pcie_phy_pkg::recovery_request = 1'b0;
      end
    join_none

    fork
      begin : rc_recovery_thread
        rc_lock.start(p_sequencer.pcie_phy_rc_ltssm_seqr_h);
        rc_lock_done = 1'b1;
        if (rc_lock.req.rsp_state == RECOVERY_ST && rc_lock.req.rsp_recovery_substate == RECOVERY_RCVR_CFG)
          rc_cfg.start(p_sequencer.pcie_phy_rc_ltssm_seqr_h);
        else
          `uvm_error(get_type_name(), $sformatf("RC RcvrLock did not reach RcvrCfg: %s/%s",
                     rc_lock.req.rsp_state.name(), rc_lock.req.rsp_recovery_substate.name()))
      end
      begin : ep_recovery_thread
        ep_lock.start(p_sequencer.pcie_phy_ep_ltssm_seqr_h);
        ep_lock_done = 1'b1;
        if (ep_lock.req.rsp_state == RECOVERY_ST && ep_lock.req.rsp_recovery_substate == RECOVERY_RCVR_CFG)
          ep_cfg.start(p_sequencer.pcie_phy_ep_ltssm_seqr_h);
        else
          `uvm_error(get_type_name(), $sformatf("EP RcvrLock did not reach RcvrCfg: %s/%s",
                     ep_lock.req.rsp_state.name(), ep_lock.req.rsp_recovery_substate.name()))
      end
    join

    if (rc_cfg.req != null && ep_cfg.req != null)
      `uvm_info(get_type_name(),
                $sformatf("RECOVERY REACHED - RcvrCfg exit: RC=%s/%s EP=%s/%s",
                          rc_cfg.req.rsp_state.name(), rc_cfg.req.rsp_recovery_substate.name(),
                          ep_cfg.req.rsp_state.name(), ep_cfg.req.rsp_recovery_substate.name()),
                UVM_LOW)
  end

endtask : body

`endif
