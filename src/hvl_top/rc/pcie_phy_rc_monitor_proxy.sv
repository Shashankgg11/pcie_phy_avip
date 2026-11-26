`ifndef PCIE_PHY_RC_MONITOR_PROXY_INCLUDED_
`define PCIE_PHY_RC_MONITOR_PROXY_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_monitor_proxy
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_monitor_proxy extends uvm_monitor;
  `uvm_component_utils(pcie_phy_rc_monitor_proxy)

  pcie_phy_rc_agent_config pcie_phy_rc_agent_cfg_h;
  virtual pcie_phy_rc_monitor_bfm pcie_phy_rc_mon_bfm_h;
  pcie_phy_rc_tx req;
  uvm_analysis_port#(pcie_phy_rc_tx) ltssm_state_analysis_port;

  //------------------------------------------------------------------------------------------
  // Persistent LTSSM tracking state - lives ACROSS forever-loop iterations.
  //------------------------------------------------------------------------------------------
  protected ltssm_state_e      cur_state;
  protected detect_substate_e  cur_detect_substate;
  protected polling_substate_e cur_polling_substate;
  protected config_substate_e  cur_config_substate;
  protected recovery_substate_e cur_recovery_substate;

  extern function new(
    string name = "pcie_phy_rc_monitor_proxy",
    uvm_component parent = null
  );
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual function void reset_ltssm_tracking();

endclass : pcie_phy_rc_monitor_proxy


function pcie_phy_rc_monitor_proxy::new(
  string name = "pcie_phy_rc_monitor_proxy",
  uvm_component parent = null
);
  super.new(name, parent);
endfunction : new


function void pcie_phy_rc_monitor_proxy::build_phase(uvm_phase phase);
  super.build_phase(phase);
  ltssm_state_analysis_port = new("ltssm_state_analysis_port", this);
  if (!uvm_config_db #(virtual pcie_phy_rc_monitor_bfm)::get(this,"","pcie_phy_rc_monitor_bfm",pcie_phy_rc_mon_bfm_h)) begin
    `uvm_fatal("FATAL_RC_MON_BFM","Couldn't get the rc monitor_bfm handle from config_db")
  end
  `uvm_info(get_type_name(),"Got the rc monitor_bfm handle from config_db",UVM_LOW)
endfunction : build_phase


function void pcie_phy_rc_monitor_proxy::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase


function void pcie_phy_rc_monitor_proxy::reset_ltssm_tracking();
  cur_state            = DETECT_ST;
  cur_detect_substate  = DETECT_QUIET;
  cur_polling_substate = POLLING_ACTIVE;
  cur_config_substate  = CFG_LINKWIDTH_START;
  cur_recovery_substate = RECOVERY_RCVR_LOCK;
endfunction : reset_ltssm_tracking


task pcie_phy_rc_monitor_proxy::run_phase(uvm_phase phase);
  detect_substate_e  next_detect_substate;
  polling_substate_e next_polling_substate;
  config_substate_e  next_config_substate;
  recovery_substate_e next_recovery_substate;
  ltssm_state_e       next_state;

  pcie_phy_rc_mon_bfm_h.rc_agent_cfg_h = pcie_phy_rc_agent_cfg_h;
  pcie_phy_rc_mon_bfm_h.wait_for_reset();

  reset_ltssm_tracking();

  forever begin

    req = pcie_phy_rc_tx::type_id::create("req");

    //--------------------------------------------------------------------------------------
    // CRITICAL FIX: monitor_l0() is only called when cur_state is actually L0_ST.
    // Previously it ran unconditionally every loop iteration and never returned
    // (since real L0 exit conditions - error threshold, excessive idle - never
    // occurred while the link was still legitimately in Detect/Polling/Configuration),
    // so the proxy never reached the state-specific dispatch below at all.
    //--------------------------------------------------------------------------------------
    if (cur_state == L0_ST) begin

      `uvm_info(get_type_name(), "Starting L0 monitoring", UVM_MEDIUM)

      pcie_phy_rc_mon_bfm_h.monitor_l0(next_state);
      req.rsp_state = next_state;

      `uvm_info(get_type_name(), $sformatf("Monitor L0 -> next_state=%s", next_state.name()), UVM_MEDIUM)

      if (next_state == DETECT_ST) reset_ltssm_tracking();
      else begin
        cur_state = next_state;
        if (next_state == RECOVERY_ST) begin
          cur_recovery_substate = RECOVERY_RCVR_LOCK;
          pcie_phy_rc_mon_bfm_h.recovery_entry();
          `uvm_info(get_type_name(), "L0 exit -> Recovery.RcvrLock", UVM_LOW)
        end
      end

    end
    else begin

      case (cur_state)

        DETECT_ST: begin
          case (cur_detect_substate)
            DETECT_QUIET: begin
              pcie_phy_rc_mon_bfm_h.monitor_detect_quiet(next_detect_substate);
              req.rsp_state           = DETECT_ST;
              req.rsp_detect_substate = next_detect_substate;
              cur_detect_substate     = next_detect_substate;
              `uvm_info(get_type_name(), $sformatf("Monitor Detect.Quiet -> %s", next_detect_substate.name()), UVM_MEDIUM)
            end
            DETECT_ACTIVE: begin
              pcie_phy_rc_mon_bfm_h.monitor_detect_active(next_state);
              req.rsp_state = next_state;
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else cur_state = next_state;
              `uvm_info(get_type_name(), $sformatf("Monitor Detect.Active -> %s", next_state.name()), UVM_MEDIUM)
            end
            default: begin
              `uvm_error(get_type_name(), $sformatf("Unhandled detect_substate_e %s", cur_detect_substate.name()))
              reset_ltssm_tracking();
            end
          endcase
        end

        POLLING_ST: begin
          case (cur_polling_substate)
            POLLING_ACTIVE: begin
              pcie_phy_rc_mon_bfm_h.monitor_polling_active(next_polling_substate, next_state);
              req.rsp_state            = next_state;
              req.rsp_polling_substate = next_polling_substate;
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else begin
                cur_state            = next_state;
                cur_polling_substate = next_polling_substate;
              end
              `uvm_info(get_type_name(), $sformatf("Monitor Polling.Active -> state=%s substate=%s", next_state.name(), next_polling_substate.name()), UVM_MEDIUM)
            end
            POLLING_CONFIG: begin
              pcie_phy_rc_mon_bfm_h.monitor_polling_configuration(next_state);
              req.rsp_state = next_state;
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else begin
                cur_state           = next_state; // CONFIG_ST
                cur_config_substate = CFG_LINKWIDTH_START;
              end
              `uvm_info(get_type_name(), $sformatf("Monitor Polling.Configuration -> %s", next_state.name()), UVM_MEDIUM)
            end
            default: begin
              `uvm_error(get_type_name(), $sformatf("Unhandled polling_substate_e %s", cur_polling_substate.name()))
              reset_ltssm_tracking();
            end
          endcase
        end

        CONFIG_ST: begin
          case (cur_config_substate)

            CFG_LINKWIDTH_START: begin
              pcie_phy_rc_mon_bfm_h.monitor_configuration_linkwidth_start(next_config_substate, next_state);
              req.rsp_state           = next_state;
              req.rsp_config_substate = next_config_substate;
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else begin
                cur_state           = next_state;
                cur_config_substate = next_config_substate;
              end
              `uvm_info(get_type_name(), $sformatf("Monitor Configuration.Linkwidth.Start -> state=%s substate=%s", next_state.name(), next_config_substate.name()), UVM_MEDIUM)
            end

            CFG_LINKWIDTH_ACCEPT: begin
              pcie_phy_rc_mon_bfm_h.monitor_configuration_linkwidth_accept(next_config_substate, next_state);
              req.rsp_state           = next_state;
              req.rsp_config_substate = next_config_substate;
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else begin
                cur_state           = next_state;
                cur_config_substate = next_config_substate;
              end
              `uvm_info(get_type_name(), $sformatf("Monitor Configuration.Linkwidth.Accept -> state=%s substate=%s", next_state.name(), next_config_substate.name()), UVM_MEDIUM)
            end

            CFG_LANENUM_WAIT: begin
              pcie_phy_rc_mon_bfm_h.monitor_configuration_lanenum_wait(next_config_substate, next_state);
              req.rsp_state           = next_state;
              req.rsp_config_substate = next_config_substate;
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else begin
                cur_state           = next_state;
                cur_config_substate = next_config_substate;
              end
              `uvm_info(get_type_name(), $sformatf("Monitor Configuration.Lanenum.Wait -> state=%s substate=%s", next_state.name(), next_config_substate.name()), UVM_MEDIUM)
            end

            CFG_LANENUM_ACCEPT: begin
              pcie_phy_rc_mon_bfm_h.monitor_configuration_lanenum_accept(next_config_substate, next_state);
              req.rsp_state           = next_state;
              req.rsp_config_substate = next_config_substate;
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else begin
                cur_state           = next_state;
                cur_config_substate = next_config_substate;
              end
              `uvm_info(get_type_name(), $sformatf("Monitor Configuration.Lanenum.Accept -> state=%s substate=%s", next_state.name(), next_config_substate.name()), UVM_MEDIUM)
            end

            CFG_COMPLETE: begin
              pcie_phy_rc_mon_bfm_h.monitor_configuration_complete(next_config_substate, next_state);
              req.rsp_state           = next_state;
              req.rsp_config_substate = next_config_substate;
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else begin
                cur_state           = next_state;
                cur_config_substate = next_config_substate;
              end
              `uvm_info(get_type_name(), $sformatf("Monitor Configuration.Complete -> state=%s substate=%s", next_state.name(), next_config_substate.name()), UVM_MEDIUM)
            end

            CFG_IDLE: begin
              pcie_phy_rc_mon_bfm_h.monitor_configuration_idle(next_state);
              req.rsp_state = next_state;
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else cur_state = next_state; // L0_ST
              `uvm_info(get_type_name(), $sformatf("Monitor Configuration.Idle -> %s", next_state.name()), UVM_MEDIUM)
            end

            default: begin
              `uvm_error(get_type_name(), $sformatf("Unhandled config_substate_e %s", cur_config_substate.name()))
              reset_ltssm_tracking();
            end
          endcase
        end

        RECOVERY_ST: begin
          case (cur_recovery_substate)
            RECOVERY_RCVR_LOCK, RECOVERY_RCVR_CFG, RECOVERY_SPEED, RECOVERY_EQ_PHASE0,
            RECOVERY_EQ_PHASE1, RECOVERY_EQ_PHASE2, RECOVERY_EQ_PHASE3, RECOVERY_IDLE: begin
              case (cur_recovery_substate)
                RECOVERY_RCVR_LOCK: pcie_phy_rc_mon_bfm_h.monitor_recovery_rcvr_lock(next_recovery_substate, next_state);
                RECOVERY_RCVR_CFG:  pcie_phy_rc_mon_bfm_h.monitor_recovery_rcvr_cfg(next_recovery_substate, next_state);
                RECOVERY_SPEED:     pcie_phy_rc_mon_bfm_h.monitor_recovery_speed(next_recovery_substate, next_state);
                RECOVERY_EQ_PHASE0: pcie_phy_rc_mon_bfm_h.monitor_recovery_eq_phase0(next_recovery_substate, next_state);
                RECOVERY_EQ_PHASE1: pcie_phy_rc_mon_bfm_h.monitor_recovery_eq_phase1(next_recovery_substate, next_state);
                RECOVERY_EQ_PHASE2: pcie_phy_rc_mon_bfm_h.monitor_recovery_eq_phase2(next_recovery_substate, next_state);
                RECOVERY_EQ_PHASE3: pcie_phy_rc_mon_bfm_h.monitor_recovery_eq_phase3(next_recovery_substate, next_state);
                default:            pcie_phy_rc_mon_bfm_h.monitor_recovery_idle(next_recovery_substate, next_state);
              endcase
              req.rsp_state              = next_state;
              req.rsp_recovery_substate  = next_recovery_substate;
              `uvm_info(get_type_name(), $sformatf("Monitor Recovery.%s -> state=%s substate=%s",
                        cur_recovery_substate.name(), next_state.name(), next_recovery_substate.name()), UVM_LOW)
              if (next_state == DETECT_ST) reset_ltssm_tracking();
              else begin
                cur_state             = next_state;
                cur_recovery_substate = next_recovery_substate;
              end
            end
            default: begin
              `uvm_error(get_type_name(), $sformatf("Unhandled recovery_substate_e %s", cur_recovery_substate.name()))
              reset_ltssm_tracking();
            end
          endcase
        end

        default: begin
          `uvm_warning(get_type_name(), $sformatf("Unsupported cur_state=%s", cur_state.name()))
          reset_ltssm_tracking();
        end

      endcase

    end

    ltssm_state_analysis_port.write(req);
    `uvm_info(get_type_name(), "RC PHY monitor transaction published", UVM_MEDIUM);

  end

endtask : run_phase

`endif
