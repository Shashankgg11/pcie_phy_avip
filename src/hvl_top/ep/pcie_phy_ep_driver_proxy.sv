`ifndef PCIE_PHY_EP_DRIVER_PROXY_INCLUDED_
`define PCIE_PHY_EP_DRIVER_PROXY_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_driver_proxy
// Driver proxy for the Endpoint (Upstream Port).
// Gets pcie_phy_ep_tx items from the sequencer and sends them to the EP driver BFM.
// Training + Recovery (RcvrLock/RcvrCfg/Speed/EQ Phase0-3/Idle) task dispatch.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_driver_proxy extends uvm_driver #(pcie_phy_ep_tx);
  `uvm_component_utils(pcie_phy_ep_driver_proxy)

  //Variable: pcie_phy_ep_agent_cfg_h
  pcie_phy_ep_agent_config pcie_phy_ep_agent_cfg_h;

  //Variable: pcie_phy_ep_drv_bfm_h
  virtual pcie_phy_ep_driver_bfm pcie_phy_ep_drv_bfm_h;

  //Variable: req
  pcie_phy_ep_tx req;

  //Variable: l0_running
  // 1 while run_l0() is alive in the background. A Recovery task is only started once
  // run_l0() has returned (it returns when it decides to leave L0).
  bit l0_running;

  //Variables: where the background run_l0() writes its exit. These are proxy members
  // (not the item) because the item is long gone by the time L0 is left.
  ltssm_state_e     l0_exit_state;
  recovery_reason_e l0_exit_reason;

  //-------------------------------------------------------
  // External Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_ep_driver_proxy", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual task wait_l0_exit();

endclass : pcie_phy_ep_driver_proxy

//--------------------------------------------------------------------------------------------
// Construct: new
//--------------------------------------------------------------------------------------------
function pcie_phy_ep_driver_proxy::new(string name = "pcie_phy_ep_driver_proxy", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_driver_proxy::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db #(virtual pcie_phy_ep_driver_bfm)::get(this, "", "pcie_phy_ep_driver_bfm", pcie_phy_ep_drv_bfm_h)) begin
    `uvm_fatal("FATAL_EP_DRV_BFM", $sformatf("Couldn't get the ep driver_bfm handle from config_db"))
  end
  `uvm_info(get_type_name(), "Got the ep driver_bfm handle from config_db", UVM_LOW)
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_driver_proxy::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Task: wait_l0_exit
// Blocks until run_l0() has returned, so Recovery starts from a clean TX/RX.
//--------------------------------------------------------------------------------------------
task pcie_phy_ep_driver_proxy::wait_l0_exit();
  if (l0_running) begin
    `uvm_info(get_type_name(), "Recovery requested - waiting for run_l0() to exit", UVM_MEDIUM)
    wait (l0_running == 1'b0);
    `uvm_info(get_type_name(),
              $sformatf("run_l0() exited, next_state=%s reason=%s", l0_exit_state.name(), l0_exit_reason.name()),
              UVM_MEDIUM)
  end
endtask : wait_l0_exit

task pcie_phy_ep_driver_proxy::run_phase(uvm_phase phase);

  detect_substate_e        verify_next_substate;
  ltssm_state_e            verify_next_state;
  bit                      verify_ei_exit;
  bit [PCIE_MAX_LANES-1:0] verify_rx_mask;

  pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h = pcie_phy_ep_agent_cfg_h;

  pcie_phy_ep_drv_bfm_h.wait_for_reset();

  forever begin
    seq_item_port.get_next_item(req);
    `uvm_info(get_type_name(),
              $sformatf("Dispatching req: target_state=%s requested_gen=%s requested_width=%s",
                        req.target_state.name(), req.requested_gen.name(), req.requested_width.name()),
              UVM_MEDIUM)

    if (req.is_bfm_verify_item) begin
      `uvm_info(get_type_name(), $sformatf("BFM-verify: exercising %s", req.requested_task.name()), UVM_LOW)
      case (req.requested_task)
        VERIFY_SEND_TS1: pcie_phy_ep_drv_bfm_h.drive_ts(
            OS_TS1,
            8'h00,
            8'h00,
            1'b0,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_autonomous_change,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_elbc,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_no_scrambling,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_loopback,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_disable_link,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_hot_reset,
            1'b0
        );
        VERIFY_SEND_TS2: pcie_phy_ep_drv_bfm_h.drive_ts(
            OS_TS2,
            8'h00,
            8'h00,
            1'b0,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_autonomous_change,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_elbc,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_no_scrambling,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_loopback,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_disable_link,
            pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h.default_hot_reset,
            1'b0
        );
        VERIFY_SEND_IDLE: pcie_phy_ep_drv_bfm_h.drive_idle();

        VERIFY_CHECK_ELECTRICAL_IDLE_EXIT: begin
          verify_ei_exit = pcie_phy_ep_drv_bfm_h.check_electrical_idle_exit_any_lane();
          `uvm_info(get_type_name(), $sformatf("check_electrical_idle_exit_any_lane() -> %0b", verify_ei_exit), UVM_LOW)
        end

        VERIFY_PERFORM_RECEIVER_DETECTION: begin
          verify_rx_mask = pcie_phy_ep_drv_bfm_h.perform_receiver_detection_all_lanes();
          `uvm_info(get_type_name(), $sformatf("perform_receiver_detection_all_lanes() -> %0h", verify_rx_mask), UVM_LOW)
        end

        VERIFY_RUN_DETECT_QUIET: begin
          pcie_phy_ep_drv_bfm_h.run_detect_quiet(verify_next_substate);
          `uvm_info(get_type_name(), $sformatf("run_detect_quiet() -> next_substate=%s", verify_next_substate.name()), UVM_LOW)
        end

        VERIFY_RUN_DETECT_ACTIVE: begin
          pcie_phy_ep_drv_bfm_h.run_detect_active(verify_next_state);
          `uvm_info(get_type_name(), $sformatf("run_detect_active() -> next_state=%s", verify_next_state.name()), UVM_LOW)
        end

        default:
          `uvm_warning(get_type_name(),
                       $sformatf("requested_task=%s has no ep driver_bfm equivalent - skipped",
                                 req.requested_task.name()))
      endcase
    end
    else begin

      //-----------------------------------------------------------------------------------
      `uvm_info(get_type_name(), $sformatf("Real dispatch: task_id=%s", req.task_id.name()), UVM_MEDIUM)

      case (req.task_id)
        LTSSM_TASK_DETECT_QUIET:
          pcie_phy_ep_drv_bfm_h.run_detect_quiet(req.rsp_detect_substate);

        LTSSM_TASK_DETECT_ACTIVE:
          pcie_phy_ep_drv_bfm_h.run_detect_active(req.rsp_state);

        LTSSM_TASK_POLLING_ACTIVE:
          pcie_phy_ep_drv_bfm_h.run_polling_active(req.rsp_polling_substate, req.rsp_state);

        LTSSM_TASK_POLLING_CONFIGURATION:
          pcie_phy_ep_drv_bfm_h.run_polling_configuration(req.rsp_polling_substate, req.rsp_state);

        LTSSM_TASK_CFG_LINKWIDTH_START:
          pcie_phy_ep_drv_bfm_h.run_linkwidth_start(req.rsp_config_substate, req.rsp_state);

        LTSSM_TASK_CFG_LINKWIDTH_ACCEPT:
          pcie_phy_ep_drv_bfm_h.run_linkwidth_accept(req.rsp_config_substate, req.rsp_state);

        LTSSM_TASK_POLLING_COMPLIANCE:
          pcie_phy_ep_drv_bfm_h.run_polling_compliance(req.rsp_polling_substate, req.rsp_state);

        LTSSM_TASK_CFG_LANENUM_WAIT:
          pcie_phy_ep_drv_bfm_h.run_configuration_lanenum_wait(req.rsp_config_substate, req.rsp_state);

        LTSSM_TASK_CFG_LANENUM_ACCEPT:
          pcie_phy_ep_drv_bfm_h.run_configuration_lanenum_accept(req.rsp_config_substate, req.rsp_state);

        LTSSM_TASK_CFG_COMPLETE:
          pcie_phy_ep_drv_bfm_h.run_configuration_complete(req.rsp_config_substate, req.rsp_state);

        LTSSM_TASK_CFG_IDLE:
          pcie_phy_ep_drv_bfm_h.run_configuration_idle(req.rsp_state);

        LTSSM_TASK_L0: begin
          //Run L0 in the background. It keeps running during normal operation and
          //returns only when it decides to leave L0. Reaching L0 means the state was
          //entered successfully. l0_running is set here (before the fork) so a
          //Recovery item can never race ahead of it.
          l0_running = 1'b1;
          fork
            begin
              pcie_phy_ep_drv_bfm_h.run_l0(l0_exit_state, l0_exit_reason);
              l0_running = 1'b0;
            end
          join_none
          req.rsp_state = L0_ST;
        end

        //---------------------------------------------------------------
        // Recovery (PCIe 6.0 spec 4.2.7.4)
        //---------------------------------------------------------------
        LTSSM_TASK_RECOVERY_RCVR_LOCK: begin
          wait_l0_exit();
          pcie_phy_ep_drv_bfm_h.run_recovery_rcvr_lock(req.rsp_state, req.rsp_recovery_substate);
        end

        LTSSM_TASK_RECOVERY_RCVR_CFG: begin
          wait_l0_exit();
          pcie_phy_ep_drv_bfm_h.run_recovery_rcvr_cfg(req.rsp_state, req.rsp_recovery_substate);
        end

        LTSSM_TASK_RECOVERY_SPEED: begin
          wait_l0_exit();
          pcie_phy_ep_drv_bfm_h.run_recovery_speed(req.rsp_state, req.rsp_recovery_substate);
        end

        LTSSM_TASK_RECOVERY_EQ_PHASE0: begin
          wait_l0_exit();
          pcie_phy_ep_drv_bfm_h.run_recovery_eq_phase0(req.rsp_state, req.rsp_recovery_substate);
        end

        LTSSM_TASK_RECOVERY_EQ_PHASE1: begin
          wait_l0_exit();
          pcie_phy_ep_drv_bfm_h.run_recovery_eq_phase1(req.rsp_state, req.rsp_recovery_substate);
        end

        LTSSM_TASK_RECOVERY_EQ_PHASE2: begin
          wait_l0_exit();
          pcie_phy_ep_drv_bfm_h.run_recovery_eq_phase2(req.rsp_state, req.rsp_recovery_substate);
        end

        LTSSM_TASK_RECOVERY_EQ_PHASE3: begin
          wait_l0_exit();
          pcie_phy_ep_drv_bfm_h.run_recovery_eq_phase3(req.rsp_state, req.rsp_recovery_substate);
        end

        LTSSM_TASK_RECOVERY_IDLE: begin
          wait_l0_exit();
          pcie_phy_ep_drv_bfm_h.run_recovery_idle(req.rsp_state, req.rsp_recovery_substate);
        end

        default:
          `uvm_error(get_type_name(),
                     $sformatf("task_id=%s has no ep driver_bfm task yet - add it to pcie_phy_ep_driver_bfm.sv first",
                               req.task_id.name()))
      endcase
    end

    seq_item_port.item_done();
  end
endtask : run_phase


`endif
