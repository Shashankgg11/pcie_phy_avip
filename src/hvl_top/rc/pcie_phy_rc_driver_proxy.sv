`ifndef PCIE_PHY_RC_DRIVER_PROXY_INCLUDED_
`define PCIE_PHY_RC_DRIVER_PROXY_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_driver_proxy
// Driver proxy for the Downstream Port (Root Complex).
// Extends uvm_driver; pulls pcie_phy_rc_tx items from the sequencer and
// drives them via the virtual pcie_phy_rc_driver_bfm handle obtained from config_db.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_driver_proxy extends uvm_driver #(pcie_phy_rc_tx);
  `uvm_component_utils(pcie_phy_rc_driver_proxy)

  //Variable: pcie_phy_rc_agent_cfg_h
  pcie_phy_rc_agent_config pcie_phy_rc_agent_cfg_h;

  //Variable: pcie_phy_rc_drv_bfm_h
  virtual pcie_phy_rc_driver_bfm pcie_phy_rc_drv_bfm_h;

  //Variable: req
  pcie_phy_rc_tx req;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_driver_proxy", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_rc_driver_proxy

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_rc_driver_proxy
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_driver_proxy::new(string name = "pcie_phy_rc_driver_proxy", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_driver_proxy::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db #(virtual pcie_phy_rc_driver_bfm)::get(this, "", "pcie_phy_rc_driver_bfm", pcie_phy_rc_drv_bfm_h)) begin
    `uvm_fatal("FATAL_RC_DRV_BFM", $sformatf("Couldn't get the rc driver_bfm handle from config_db"))
  end
  `uvm_info(get_type_name(), "Got the rc driver_bfm handle from config_db", UVM_LOW)
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_driver_proxy::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
// Waits for reset once, then forever pulls items from the sequencer and dispatches them to
// the matching pcie_phy_rc_drv_bfm_h task based on req.target_state. This is the one place
// that maps an LTSSM state directive onto an actual bit-serial driver_bfm task - extend the
// case statement here whenever a new state/task is added to the driver_bfm.
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------

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
          pcie_phy_rc_drv_bfm_h.drive_ts(
              OS_TS1,
              8'h00,
              8'h00,
              1'b0,
              1'b0
          );

        VERIFY_SEND_TS2:
          pcie_phy_rc_drv_bfm_h.drive_ts(
              OS_TS2,
              8'h00,
              8'h00,
              1'b0,
              1'b0
          );

        VERIFY_SEND_IDLE:
          pcie_phy_rc_drv_bfm_h.drive_idle();

        default:
          `uvm_warning(get_type_name(),
                       $sformatf("requested_task=%s has no rc driver_bfm equivalent - skipped",
                                 req.requested_task.name()))

      endcase

    end
    else begin

      case (req.target_state)

        DETECT_ST,
        POLLING_ST,
        RECOVERY_ST:
          pcie_phy_rc_drv_bfm_h.drive_ts(
              OS_TS1,
              8'h00,
              8'h00,
              1'b0,
              1'b0
          );

        CONFIG_ST:
          pcie_phy_rc_drv_bfm_h.drive_ts(
              OS_TS2,
              8'h00,
              8'h00,
              1'b0,
              1'b0
          );

        L0_ST,
        L0s_ST,
        L1_ST:
          pcie_phy_rc_drv_bfm_h.drive_idle();

        default:
          `uvm_warning(get_type_name(),
                       $sformatf("No driver_bfm dispatch defined yet for target_state=%s - add a case here",
                                 req.target_state.name()))

      endcase

    end

    seq_item_port.item_done();

  end

endtask : run_phase

`endif
