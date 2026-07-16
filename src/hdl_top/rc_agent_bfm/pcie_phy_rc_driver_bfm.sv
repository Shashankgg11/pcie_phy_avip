`ifndef PCIE_PHY_RC_DRIVER_BFM_INCLUDED_
`define PCIE_PHY_RC_DRIVER_BFM_INCLUDED_

import pcie_phy_globals_pkg::*;

//--------------------------------------------------------------------------------------------
// Interface: pcie_phy_rc_driver_bfm
// Used as the HDL driver for the Downstream Port (Root Complex).
// It connects with the HVL driver_proxy for driving the stimulus.
//--------------------------------------------------------------------------------------------
interface pcie_phy_rc_driver_bfm(input bit aclk, input bit aresetn,
                                    output reg [7:0] rc_tx_symbol [NUM_LANES],
                                    output reg        rc_tx_electrical_idle [NUM_LANES],
                                    input  [7:0]      ep_tx_symbol [NUM_LANES],
                                    input             ep_tx_electrical_idle [NUM_LANES],
                                    output reg         rc_rx_receiver_present [NUM_LANES],
                                    output reg         rc_rx_electrical_idle_exit [NUM_LANES]);

  // Proof-of-life marker — fires once at t=0 so `make simulate` shows
  // visible evidence the driver_bfm elaborated and is alive.
  initial begin
    $display("[%0t] RC_DRIVER_BFM : Driver BFM Started", $time);
  end

  task wait_for_aresetn();
    @(posedge aresetn);
  endtask : wait_for_aresetn

  // ── DETECT state tasks ──────────────────────
  task run_detect_quiet(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — detect state
    // Reference: detect_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_detect_quiet

  task run_detect_active(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — detect state
    // Reference: detect_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_detect_active

  // ── POLLING state tasks ──────────────────────
  task run_polling_active(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — polling state
    // Reference: polling_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_polling_active

  task run_polling_compliance(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — polling state
    // Reference: polling_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_polling_compliance

  task run_polling_configuration(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — polling state
    // Reference: polling_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_polling_configuration

  // ── CONFIGURATION state tasks ──────────────────────
  task run_linkwidth_start(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — configuration state
    // Reference: configuration_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_linkwidth_start

  task run_linkwidth_accept(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — configuration state
    // Reference: configuration_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_linkwidth_accept

  task run_lanenum_wait(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — configuration state
    // Reference: configuration_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_lanenum_wait

  task run_lanenum_accept(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — configuration state
    // Reference: configuration_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_lanenum_accept

  task run_config_complete(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — configuration state
    // Reference: configuration_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_config_complete

  task run_config_idle(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — configuration state
    // Reference: configuration_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_config_idle

  // ── RECOVERY state tasks ──────────────────────
  task run_rcvrlock(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — recovery state
    // Reference: recovery_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_rcvrlock

  task run_equalization(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — recovery state
    // Reference: recovery_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_equalization

  task run_speed(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — recovery state
    // Reference: recovery_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_speed

  task run_rcvrcfg(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — recovery state
    // Reference: recovery_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_rcvrcfg

  task run_idle(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — recovery state
    // Reference: recovery_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_idle

  // ── L0 state tasks ──────────────────────
  task run_l0(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — l0 state
    // Reference: l0_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_l0

  // ── L0S state tasks ──────────────────────
  task run_rx_l0s_entry(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — l0s state
    // Reference: l0s_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_rx_l0s_entry

  task run_rx_l0s_idle(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — l0s state
    // Reference: l0s_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_rx_l0s_idle

  task run_rx_l0s_fts(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — l0s state
    // Reference: l0s_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_rx_l0s_fts

  task run_tx_l0s_entry(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — l0s state
    // Reference: l0s_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_tx_l0s_entry

  task run_tx_l0s_idle(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — l0s state
    // Reference: l0s_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_tx_l0s_idle

  task run_tx_l0s_fts(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — l0s state
    // Reference: l0s_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_tx_l0s_fts

  // ── L1 state tasks ──────────────────────
  task run_l1_entry(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — l1 state
    // Reference: l1_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_l1_entry

  task run_l1_idle(output next_state_e next);
    // TODO: implement per PCIe Gen6 Logical PHY spec — l1 state
    // Reference: l1_state.pdf (BFM Implementation Spec)
    next = NEXT_NONE;
  endtask : run_l1_idle

  task default_values();
    $display("[%0t] RC_DRIVER_BFM : Driving default values (Electrical Idle) on all lanes", $time);
    // TODO: drive Electrical Idle / reset defaults on all lanes
  endtask : default_values

endinterface : pcie_phy_rc_driver_bfm

`endif
