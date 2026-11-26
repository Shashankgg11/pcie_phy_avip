`ifndef PCIE_PHY_EP_RECOVERY_EQUALIZATION_SEQ_INCLUDED_
`define PCIE_PHY_EP_RECOVERY_EQUALIZATION_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_recovery_equalization_seq
// Recovery.Equalization sequence for the Upstream Port (Endpoint)
//
// Spec: PCI Express Base Spec 6.0, 4.2.7.4.2 Recovery.Equalization
//       4.2.7.4.2.2 Upstream Lanes (Phase 0, 1, 2, 3)
//
// The sequence sends the task_id of the chosen phase, then reads the result back from the same
// item (rsp_state / rsp_recovery_substate, filled in by the driver_proxy) and checks that the
// exit is one the spec allows.
//
// Legal exits (the same set for both ports, the cause and the timeout differ):
//   Phase 0 (Upstream only)  Phase 1 | Recovery.Speed | Loopback.Entry
//   Phase 1                  Phase 2 | Recovery.RcvrLock | Recovery.Speed | Loopback.Entry
//   Phase 2                  Phase 3 | Recovery.Speed | Loopback.Entry
//   Phase 3                  Recovery.RcvrLock | Recovery.Speed | Loopback.Entry
//   Detect is not an arc in any phase.
//
// Timeouts to Recovery.Speed / Loopback.Entry (64 GT/s doubles the Phase 2 and Phase 3 values):
//                 Downstream   Upstream
//   Phase 0       none         12 ms
//   Phase 1       24 ms        12 ms
//   Phase 2       32 ms        24 ms
//   Phase 3       24 ms        32 ms
//
// Who adjusts whom: in Phase 2 the Upstream Port requests the Downstream Port's transmitter
// settings, in Phase 3 the Downstream Port requests the Upstream Port's.
//
// Knobs:
//   eq_phase    phase to run (first phase when run_all = 1)
//   run_all     1 = keep going while the driver reports the next phase, stop at the first exit
//               that is not the next phase
//   check_exit  1 = also require the last exit to be exp_state / exp_substate
//
// Not visible to a sequence: the TS0/TS1 content (EC field, presets, coefficients, Reject
// Coefficient Values, Use Preset), request/evaluation timing and the Link Status register bits.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_recovery_equalization_seq extends uvm_sequence #(pcie_phy_ep_tx);
  `uvm_object_utils(pcie_phy_ep_recovery_equalization_seq)

  // 0 = Downstream Lanes (Root Complex), 1 = Upstream Lanes (Endpoint)
  localparam bit IS_UPSTREAM = 1'b1;

  pcie_phy_ep_tx req;

  eq_phase_e          eq_phase;
  bit                 run_all;
  bit                 check_exit;
  ltssm_state_e       exp_state;
  recovery_substate_e exp_substate;

  //-------------------------------------------------------
  // Construct
  //-------------------------------------------------------
  function new(string name = "pcie_phy_ep_recovery_equalization_seq");
    super.new(name);
    eq_phase = EQ_PHASE0;
  endfunction : new

  //-------------------------------------------------------
  // Helpers
  //-------------------------------------------------------
  function pcie_phy_ltssm_task_e phase_to_task(eq_phase_e p);
    case (p)
      EQ_PHASE0: return LTSSM_TASK_RECOVERY_EQ_PHASE0;
      EQ_PHASE1: return LTSSM_TASK_RECOVERY_EQ_PHASE1;
      EQ_PHASE2: return LTSSM_TASK_RECOVERY_EQ_PHASE2;
      default:   return LTSSM_TASK_RECOVERY_EQ_PHASE3;
    endcase
  endfunction : phase_to_task

  function recovery_substate_e phase_substate(eq_phase_e p);
    case (p)
      EQ_PHASE0: return RECOVERY_EQ_PHASE0;
      EQ_PHASE1: return RECOVERY_EQ_PHASE1;
      EQ_PHASE2: return RECOVERY_EQ_PHASE2;
      default:   return RECOVERY_EQ_PHASE3;
    endcase
  endfunction : phase_substate

  // Timeout in the spec text for this port and phase, below 64 GT/s
  function string timeout_str(eq_phase_e p);
    case (p)
      EQ_PHASE0: return "12 ms";
      EQ_PHASE1: return IS_UPSTREAM ? "12 ms" : "24 ms";
      EQ_PHASE2: return IS_UPSTREAM ? "24 ms" : "32 ms";
      default:   return IS_UPSTREAM ? "32 ms" : "24 ms";
    endcase
  endfunction : timeout_str

  // Recovery substates reachable from phase p
  function bit legal_recovery_exit(eq_phase_e p, recovery_substate_e s);
    case (p)
      EQ_PHASE0: return (s == RECOVERY_EQ_PHASE1) || (s == RECOVERY_SPEED);
      EQ_PHASE1: return (s == RECOVERY_EQ_PHASE2) || (s == RECOVERY_RCVR_LOCK) || (s == RECOVERY_SPEED);
      EQ_PHASE2: return (s == RECOVERY_EQ_PHASE3) || (s == RECOVERY_SPEED);
      default:   return (s == RECOVERY_RCVR_LOCK) || (s == RECOVERY_SPEED);
    endcase
  endfunction : legal_recovery_exit

  function bit exit_is_legal(eq_phase_e p, ltssm_state_e st, recovery_substate_e sub);
    if (st == LOOPBACK_ST) return 1'b1;   // Loopback.Entry, perform_equalization_for_loopback = 1
    if (st != RECOVERY_ST) return 1'b0;   // Detect and the others are not arcs in these phases
    return legal_recovery_exit(p, sub);
  endfunction : exit_is_legal

  function string describe_exit(eq_phase_e p, ltssm_state_e st, recovery_substate_e sub);
    if (st == LOOPBACK_ST)
      return $sformatf("Loopback.Entry (%s timeout or loopback condition, perform_equalization_for_loopback = 1)",
                       timeout_str(p));
    if (st == RECOVERY_ST) begin
      case (sub)
        RECOVERY_SPEED:     return $sformatf("Recovery.Speed (%s timeout, successful_speed_negotiation = 0)",
                                             timeout_str(p));
        RECOVERY_RCVR_LOCK: return "Recovery.RcvrLock";
        RECOVERY_EQ_PHASE1: return "Phase 1";
        RECOVERY_EQ_PHASE2: return "Phase 2";
        RECOVERY_EQ_PHASE3: return "Phase 3";
        default:            return sub.name();
      endcase
    end
    return st.name();
  endfunction : describe_exit

  //-------------------------------------------------------
  // Run one phase: send the request, classify the exit
  //-------------------------------------------------------
  task run_once(eq_phase_e p, output bit legal_exit, output bit advanced);
    eq_phase_e next_p;

    legal_exit = 1'b0;
    advanced   = 1'b0;

    `uvm_info(get_type_name(),
              $sformatf("Starting Recovery.Equalization Phase %0d (%s)",
                        p, IS_UPSTREAM ? "Upstream Lanes" : "Downstream Lanes"),
              UVM_MEDIUM)

    req = pcie_phy_ep_tx::type_id::create("req");
    start_item(req);
    if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")

    req.is_bfm_verify_item = 1'b0;               // real LTSSM dispatch, not BFM-verify
    req.task_id            = phase_to_task(p);   // proxy calls run_recovery_eq_phaseN()
    finish_item(req);                            // returns after the driver task returns

    legal_exit = exit_is_legal(p, req.rsp_state, req.rsp_recovery_substate);

    if (!IS_UPSTREAM && (p == EQ_PHASE0)) begin
      // Downstream Lanes start at Phase 1, so there is no spec arc to check against
      legal_exit = 1'b1;
      `uvm_warning(get_type_name(),
                    $sformatf("Downstream Lanes have no Phase 0 in the spec; exit (%s) is not checked",
                              describe_exit(p, req.rsp_state, req.rsp_recovery_substate)))
    end
    else if (legal_exit) begin
      if ((req.rsp_state == RECOVERY_ST) && (req.rsp_recovery_substate == RECOVERY_SPEED)) begin
        `uvm_warning(get_type_name(),
                      $sformatf("Phase %0d -> %s", p,
                                describe_exit(p, req.rsp_state, req.rsp_recovery_substate)))
      end
      else begin
        `uvm_info(get_type_name(),
                   $sformatf("Phase %0d -> %s", p,
                             describe_exit(p, req.rsp_state, req.rsp_recovery_substate)),
                   UVM_LOW)
      end
    end
    else begin
      `uvm_error(get_type_name(),
                  $sformatf("Phase %0d: exit %s / %s is not a legal arc (%s Lanes)",
                            p, req.rsp_state.name(), req.rsp_recovery_substate.name(),
                            IS_UPSTREAM ? "Upstream" : "Downstream"))
    end

    // Did the driver move on to the next phase?
    if (legal_exit && (req.rsp_state == RECOVERY_ST) && (p != EQ_PHASE3)) begin
      next_p   = eq_phase_e'(p + 1'b1);
      advanced = (req.rsp_recovery_substate == phase_substate(next_p));
    end
  endtask : run_once

  //-------------------------------------------------------
  // Body
  //-------------------------------------------------------
  task body();
    eq_phase_e cur;
    bit        legal_exit;
    bit        advanced;

    cur = eq_phase;

    forever begin
      run_once(cur, legal_exit, advanced);
      if (!run_all || !advanced) break;
      cur = eq_phase_e'(cur + 1'b1);
    end

    // Optional: require one specific exit from the last phase that ran
    if (check_exit && legal_exit) begin
      if (req.rsp_state != exp_state) begin
        `uvm_error(get_type_name(),
                    $sformatf("Exit mismatch: expected state %s, got %s",
                              exp_state.name(), req.rsp_state.name()))
      end
      else if ((req.rsp_state == RECOVERY_ST) && (req.rsp_recovery_substate != exp_substate)) begin
        `uvm_error(get_type_name(),
                    $sformatf("Exit mismatch: expected substate %s, got %s",
                              exp_substate.name(), req.rsp_recovery_substate.name()))
      end
      else begin
        `uvm_info(get_type_name(), "Recovery.Equalization exit matches the expected exit", UVM_LOW)
      end
    end
  endtask : body

endclass : pcie_phy_ep_recovery_equalization_seq

`endif
