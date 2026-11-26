`ifndef PCIE_PHY_RC_DRIVER_PROXY_INCLUDED_
`define PCIE_PHY_RC_DRIVER_PROXY_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_driver_proxy
// Driver proxy for the Root Complex (Downstream Port).
// Gets pcie_phy_rc_tx items from the sequencer and sends them to the RC driver BFM.
// Training + Recovery (RcvrLock/RcvrCfg/Speed/EQ Phase0-3/Idle) task dispatch.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_driver_proxy extends uvm_driver #(pcie_phy_rc_tx);
  `uvm_component_utils(pcie_phy_rc_driver_proxy)

  //Variable: pcie_phy_rc_agent_cfg_h
  pcie_phy_rc_agent_config pcie_phy_rc_agent_cfg_h;

  //Variable: pcie_phy_rc_drv_bfm_h
  virtual pcie_phy_rc_driver_bfm pcie_phy_rc_drv_bfm_h;

  //Variable: req
  pcie_phy_rc_tx req;

  //Variable: l0_running
  // 1 while run_l0() is alive in the background. A Recovery task is only started once
  // run_l0() has returned (it returns when it decides to leave L0).
  bit l0_running;

  //-------------------------------------------------------
  // External Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_driver_proxy", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual task wait_l0_exit();

endclass : pcie_phy_rc_driver_proxy

function pcie_phy_rc_driver_proxy::new(string name = "pcie_phy_rc_driver_proxy", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void pcie_phy_rc_driver_proxy::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db #(virtual pcie_phy_rc_driver_bfm)::get(this, "", "pcie_phy_rc_driver_bfm", pcie_phy_rc_drv_bfm_h)) begin
    `uvm_fatal("FATAL_RC_DRV_BFM", $sformatf("Couldn't get the rc driver_bfm handle from config_db"))
  end
  `uvm_info(get_type_name(), "Got the rc driver_bfm handle from config_db", UVM_LOW)
endfunction : build_phase

function void pcie_phy_rc_driver_proxy::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Task: wait_l0_exit
// Blocks until run_l0() has returned, so Recovery starts from a clean TX/RX.
//--------------------------------------------------------------------------------------------
task pcie_phy_rc_driver_proxy::wait_l0_exit();
  if (l0_running) begin
    `uvm_info(get_type_name(), "Recovery requested - waiting for run_l0() to exit", UVM_MEDIUM)
    wait (l0_running == 1'b0);
    `uvm_info(get_type_name(),
              $sformatf("run_l0() exited, reason=%s", pcie_phy_rc_drv_bfm_h.next_recovery_reason.name()),
              UVM_MEDIUM)
  end
endtask : wait_l0_exit

task pcie_phy_rc_driver_proxy::run_phase(uvm_phase phase);

  pcie_phy_rc_drv_bfm_h.rc_agent_cfg_h = pcie_phy_rc_agent_cfg_h;

  pcie_phy_rc_drv_bfm_h.wait_for_reset();

  forever begin

    seq_item_port.get_next_item(req);

    `uvm_info(get_type_name(),
              $sformatf("Dispatching req: target_state=%s requested_gen=%s requested_width=%s",
                        req.target_state.name(),
                        req.requested_gen.name(),
                        req.requested_width.name()),
              UVM_MEDIUM)

    if (req.is_bfm_verify_item) begin

      `uvm_info(get_type_name(),
                $sformatf("BFM-verify: exercising %s",
                          req.requested_task.name()),
                UVM_LOW)

      case (req.requested_task)

        VERIFY_SEND_TS1:
          pcie_phy_rc_drv_bfm_h.drive_ts(OS_TS1,8'h00,8'h00,1'b0,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b0);

        VERIFY_SEND_TS2:
          pcie_phy_rc_drv_bfm_h.drive_ts(OS_TS2,8'h00,8'h00,1'b0,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b0);

        VERIFY_SEND_IDLE:
          pcie_phy_rc_drv_bfm_h.drive_idle();

        default:
          `uvm_warning(get_type_name(),
                       $sformatf("requested_task=%s has no rc driver_bfm equivalent - skipped",
                                 req.requested_task.name()))

      endcase

    end
    else begin

      `uvm_info(get_type_name(), $sformatf("Real dispatch: task_id=%s", req.task_id.name()), UVM_MEDIUM)

      case (req.task_id)
        LTSSM_TASK_DETECT_QUIET:
          pcie_phy_rc_drv_bfm_h.run_detect_quiet();

        LTSSM_TASK_DETECT_ACTIVE:
          pcie_phy_rc_drv_bfm_h.run_detect_active();

        LTSSM_TASK_POLLING_ACTIVE:
          pcie_phy_rc_drv_bfm_h.run_polling_active();

        LTSSM_TASK_POLLING_CONFIGURATION:
          pcie_phy_rc_drv_bfm_h.run_polling_configuration();

        LTSSM_TASK_CFG_LINKWIDTH_START:
          pcie_phy_rc_drv_bfm_h.run_linkwidth_start();

        LTSSM_TASK_CFG_LINKWIDTH_ACCEPT:
          pcie_phy_rc_drv_bfm_h.run_linkwidth_accept();

        LTSSM_TASK_POLLING_COMPLIANCE:
          pcie_phy_rc_drv_bfm_h.run_polling_compliance();

        LTSSM_TASK_CFG_LANENUM_WAIT:
          pcie_phy_rc_drv_bfm_h.run_configuration_lanenum_wait();

        LTSSM_TASK_CFG_LANENUM_ACCEPT:
          pcie_phy_rc_drv_bfm_h.run_configuration_lanenum_accept();

        LTSSM_TASK_CFG_COMPLETE:
          pcie_phy_rc_drv_bfm_h.run_configuration_complete();

        LTSSM_TASK_CFG_IDLE:
          pcie_phy_rc_drv_bfm_h.run_configuration_idle();

        LTSSM_TASK_L0: begin
          //run_l0() keeps running during normal operation and only returns when
          //a condition causes Recovery. Reaching L0 means the training is complete.
          //l0_running is set here (before the fork) so a Recovery item can never
          //race ahead of it.
          l0_running = 1'b1;
          fork
            begin
              pcie_phy_rc_drv_bfm_h.run_l0();
              l0_running = 1'b0;
            end
          join_none
          pcie_phy_rc_drv_bfm_h.next_state = L0_ST;
        end

        //---------------------------------------------------------------
        // Recovery (PCIe 6.0 spec 4.2.7.4) - each task leaves the next state in
        // next_state / next_recovery_substate
        //---------------------------------------------------------------
        LTSSM_TASK_RECOVERY_RCVR_LOCK: begin
          wait_l0_exit();
          pcie_phy_rc_drv_bfm_h.run_recovery_rcvr_lock();
        end

        LTSSM_TASK_RECOVERY_RCVR_CFG: begin
          wait_l0_exit();
          pcie_phy_rc_drv_bfm_h.run_recovery_rcvr_cfg();
        end

        LTSSM_TASK_RECOVERY_SPEED: begin
          wait_l0_exit();
          pcie_phy_rc_drv_bfm_h.run_recovery_speed();
        end

        LTSSM_TASK_RECOVERY_EQ_PHASE0: begin
          wait_l0_exit();
          pcie_phy_rc_drv_bfm_h.run_recovery_eq_phase0();
        end

        LTSSM_TASK_RECOVERY_EQ_PHASE1: begin
          wait_l0_exit();
          pcie_phy_rc_drv_bfm_h.run_recovery_eq_phase1();
        end

        LTSSM_TASK_RECOVERY_EQ_PHASE2: begin
          wait_l0_exit();
          pcie_phy_rc_drv_bfm_h.run_recovery_eq_phase2();
        end

        LTSSM_TASK_RECOVERY_EQ_PHASE3: begin
          wait_l0_exit();
          pcie_phy_rc_drv_bfm_h.run_recovery_eq_phase3();
        end

        LTSSM_TASK_RECOVERY_IDLE: begin
          wait_l0_exit();
          pcie_phy_rc_drv_bfm_h.run_recovery_idle();
        end

        default:
          `uvm_fatal(get_type_name(), $sformatf("Unhandled task_id %s", req.task_id.name()))
      endcase

      req.rsp_state              = pcie_phy_rc_drv_bfm_h.next_state;
      req.rsp_detect_substate    = pcie_phy_rc_drv_bfm_h.next_detect_substate;
      req.rsp_polling_substate   = pcie_phy_rc_drv_bfm_h.next_polling_substate;
      req.rsp_config_substate    = pcie_phy_rc_drv_bfm_h.next_config_substate;
      req.rsp_recovery_substate  = pcie_phy_rc_drv_bfm_h.next_recovery_substate;

    end

    seq_item_port.item_done();

  end

endtask : run_phase

`endif
