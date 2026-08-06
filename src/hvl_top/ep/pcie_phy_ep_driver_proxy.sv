`ifndef PCIE_PHY_EP_DRIVER_PROXY_INCLUDED_
`define PCIE_PHY_EP_DRIVER_PROXY_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_driver_proxy
// Driver proxy for the Upstream Port (Endpoint).
// Extends uvm_driver; pulls pcie_phy_ep_tx items from the sequencer and
// drives them via the virtual pcie_phy_ep_driver_bfm handle obtained from config_db.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_driver_proxy extends uvm_driver #(pcie_phy_ep_tx);
  `uvm_component_utils(pcie_phy_ep_driver_proxy)

  //Variable: pcie_phy_ep_agent_cfg_h
  pcie_phy_ep_agent_config pcie_phy_ep_agent_cfg_h;

  //Variable: pcie_phy_ep_drv_bfm_h
  virtual pcie_phy_ep_driver_bfm pcie_phy_ep_drv_bfm_h;

  //Variable: req
  pcie_phy_ep_tx req;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_ep_driver_proxy", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_ep_driver_proxy

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_ep_driver_proxy
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_ep_driver_proxy::new(string name = "pcie_phy_ep_driver_proxy", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
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
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_driver_proxy::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
// Waits for reset once, then forever pulls items from the sequencer and dispatches them to
// the matching pcie_phy_ep_drv_bfm_h task based on req.target_state. Mirrors
// pcie_phy_rc_driver_proxy - extend the case statement here whenever a new state/task is
// added to the driver_bfm (note: ep_driver_bfm.sv also has run_detect_quiet/run_detect_active/
// receiver-detection tasks not dispatched here yet - those need their own state-machine loop
// around them rather than a single call per item, so they're intentionally left out for now).
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_ep_driver_proxy::run_phase(uvm_phase phase);
  //Local captures for driver_bfm tasks/functions with output args or return values - only
  //used by the BFM-verify path below, values aren't acted on (no protocol meaning here).
  detect_substate_e        verify_next_substate;
  ltssm_state_e             verify_next_state;
  bit                       verify_ei_exit;
  bit [PCIE_MAX_LANES-1:0]  verify_rx_mask;

  //Propagate the agent config into the BFM's own handle - see rc_driver_proxy for why this
  //has to happen in run_phase rather than build/connect_phase.
  pcie_phy_ep_drv_bfm_h.ep_agent_cfg_h = pcie_phy_ep_agent_cfg_h;

  pcie_phy_ep_drv_bfm_h.wait_for_reset();

  forever begin
    seq_item_port.get_next_item(req);
    `uvm_info(get_type_name(),
              $sformatf("Dispatching req: target_state=%s requested_gen=%s requested_width=%s",
                        req.target_state.name(), req.requested_gen.name(), req.requested_width.name()),
              UVM_MEDIUM)

    if (req.is_bfm_verify_item) begin
      //-----------------------------------------------------------------------------------
      // Verification path: dispatch strictly off requested_task, no protocol meaning.
      //-----------------------------------------------------------------------------------
      `uvm_info(get_type_name(), $sformatf("BFM-verify: exercising %s", req.requested_task.name()), UVM_LOW)
      case(req.requested_task)
        VERIFY_SEND_TS1:pcie_phy_ep_drv_bfm_h.drive_ts(
    OS_TS1,
    8'h00,
    8'h00,
    1'b0,
    1'b0
);
        VERIFY_SEND_TS2:pcie_phy_ep_drv_bfm_h.drive_ts(
    OS_TS2,
    8'h00,
    8'h00,
    1'b0,
    1'b0
);
        VERIFY_SEND_IDLE:pcie_phy_ep_drv_bfm_h.drive_idle();

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
