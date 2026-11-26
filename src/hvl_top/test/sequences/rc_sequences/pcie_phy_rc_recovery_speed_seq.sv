`ifndef PCIE_PHY_RC_RECOVERY_SPEED_SEQ_INCLUDED_
`define PCIE_PHY_RC_RECOVERY_SPEED_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_recovery_speed_seq
// Recovery.Speed sequence for the Downstream Port (Root Complex)
// Spec: PCI Express Base Spec 6.0, 4.2.7.4.3. Sends the task_id, reads rsp_state /
// rsp_recovery_substate back from the same item and checks the exit is a spec arc.
// check_exit = 1 additionally requires exp_state / exp_substate.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_recovery_speed_seq extends uvm_sequence #(pcie_phy_rc_tx);
  `uvm_object_utils(pcie_phy_rc_recovery_speed_seq)

  pcie_phy_rc_tx req;

  bit                 check_exit;
  ltssm_state_e       exp_state;
  recovery_substate_e exp_substate;

  function new(string name = "pcie_phy_rc_recovery_speed_seq");
    super.new(name);
  endfunction : new

  task body();
    bit legal_exit;

    `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

    req = pcie_phy_rc_tx::type_id::create("req");
    start_item(req);
    if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
    req.is_bfm_verify_item = 1'b0;
    req.task_id            = LTSSM_TASK_RECOVERY_SPEED;
    finish_item(req);

    legal_exit = 1'b0;

    case (req.rsp_state)

      RECOVERY_ST: begin
        case (req.rsp_recovery_substate)
          RECOVERY_RCVR_LOCK: begin legal_exit = 1'b1; `uvm_info(get_type_name(), "Recovery.Speed -> Recovery.RcvrLock (data rate changed or reverted)", UVM_LOW) end
          default: `uvm_error(get_type_name(), $sformatf("Recovery.Speed: %s is not a legal exit", req.rsp_recovery_substate.name()))
        endcase
      end

      DETECT_ST: begin
        legal_exit = 1'b1; `uvm_warning(get_type_name(), "Recovery.Speed -> Detect (48 ms timeout, not expected under normal conditions)")
        if (req.rsp_detect_substate != DETECT_QUIET)
          `uvm_error(get_type_name(), $sformatf("Detect must be entered at Detect.Quiet, got %s", req.rsp_detect_substate.name()))
      end

      default: `uvm_error(get_type_name(), $sformatf("Recovery.Speed: unexpected rsp_state %s", req.rsp_state.name()))
    endcase

    if (check_exit && legal_exit) begin
      if (req.rsp_state != exp_state)
        `uvm_error(get_type_name(), $sformatf("Exit mismatch: expected state %s, got %s", exp_state.name(), req.rsp_state.name()))
      else if ((req.rsp_state == RECOVERY_ST) && (req.rsp_recovery_substate != exp_substate))
        `uvm_error(get_type_name(), $sformatf("Exit mismatch: expected substate %s, got %s", exp_substate.name(), req.rsp_recovery_substate.name()))
      else
        `uvm_info(get_type_name(), "Exit matches the expected exit", UVM_LOW)
    end
  endtask : body

endclass : pcie_phy_rc_recovery_speed_seq

`endif
