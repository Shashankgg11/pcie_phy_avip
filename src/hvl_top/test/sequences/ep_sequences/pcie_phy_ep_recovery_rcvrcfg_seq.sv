`ifndef PCIE_PHY_EP_RECOVERY_RCVRCFG_SEQ_INCLUDED_
`define PCIE_PHY_EP_RECOVERY_RCVRCFG_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_recovery_rcvrcfg_seq
// Recovery.RcvrCfg sequence for the Upstream Port (Endpoint)
// Spec: PCI Express Base Spec 6.0, 4.2.7.4.4. Sends the task_id, reads rsp_state /
// rsp_recovery_substate back from the same item and checks the exit is a spec arc.
// check_exit = 1 additionally requires exp_state / exp_substate.
// The spec has NO RcvrCfg -> Equalization arc (equalization is entered from RcvrLock).
// allow_eq_from_rcvrcfg = 1 accepts the EQ_PHASE0 exit the current driver returns at Gen3+.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_recovery_rcvrcfg_seq extends uvm_sequence #(pcie_phy_ep_tx);
  `uvm_object_utils(pcie_phy_ep_recovery_rcvrcfg_seq)

  pcie_phy_ep_tx req;

  bit                 check_exit;
  ltssm_state_e       exp_state;
  recovery_substate_e exp_substate;
  bit                 allow_eq_from_rcvrcfg;

  function new(string name = "pcie_phy_ep_recovery_rcvrcfg_seq");
    super.new(name);
  endfunction : new

  task body();
    bit legal_exit;

    `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

    req = pcie_phy_ep_tx::type_id::create("req");
    start_item(req);
    if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
    req.is_bfm_verify_item = 1'b0;
    req.task_id            = LTSSM_TASK_RECOVERY_RCVR_CFG;
    finish_item(req);

    legal_exit = 1'b0;

    case (req.rsp_state)

      RECOVERY_ST: begin
        case (req.rsp_recovery_substate)
          RECOVERY_SPEED: begin legal_exit = 1'b1; `uvm_info(get_type_name(), "RcvrCfg -> Recovery.Speed (8 TS2 with speed_change, or Electrical Idle revert)", UVM_LOW) end
          RECOVERY_IDLE: begin legal_exit = 1'b1; `uvm_info(get_type_name(), "RcvrCfg -> Recovery.Idle (8 TS2 matching, 16 TS2 sent)", UVM_LOW) end
          RECOVERY_EQ_PHASE0: begin
            if (allow_eq_from_rcvrcfg) begin legal_exit = 1'b1; `uvm_warning(get_type_name(), "RcvrCfg -> EQ Phase 0 (driver arc, not in spec)") end
            else `uvm_error(get_type_name(), "RcvrCfg -> EQ Phase 0 is not a spec arc; equalization is entered from RcvrLock")
          end
          default: `uvm_error(get_type_name(), $sformatf("Recovery.RcvrCfg: %s is not a legal exit", req.rsp_recovery_substate.name()))
        endcase
      end

      CONFIG_ST: begin
        legal_exit = 1'b1; `uvm_info(get_type_name(), "RcvrCfg -> Configuration (8 TS1 with Link/Lane mismatch)", UVM_LOW)
      end

      LOOPBACK_ST: begin
        legal_exit = 1'b1; `uvm_info(get_type_name(), "RcvrCfg -> Loopback (directed)", UVM_LOW)
      end

      DETECT_ST: begin
        legal_exit = 1'b1; `uvm_warning(get_type_name(), "RcvrCfg -> Detect (48 ms timeout / no valid exit condition)")
      end

      default: `uvm_error(get_type_name(), $sformatf("Recovery.RcvrCfg: unexpected rsp_state %s", req.rsp_state.name()))
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

endclass : pcie_phy_ep_recovery_rcvrcfg_seq

`endif
