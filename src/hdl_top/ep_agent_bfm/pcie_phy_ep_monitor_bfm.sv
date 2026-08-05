`ifndef PCIE_PHY_EP_MONITOR_BFM_INCLUDED_
`define PCIE_PHY_EP_MONITOR_BFM_INCLUDED_

import pcie_phy_pkg::*;

//--------------------------------------------------------------------------------------------
// Interface: pcie_phy_ep_monitor_bfm
// Passive shadow-LTSSM monitor BFM for the Upstream Port (Endpoint).
// Samples link signals through the interface but cannot drive them.
//--------------------------------------------------------------------------------------------
interface pcie_phy_ep_monitor_bfm(input logic pclk, input logic preset_n,
                                  input logic [PCIE_MAX_LANES-1:0] RX_P,
                                  input logic [PCIE_MAX_LANES-1:0] RX_N);

  // Proof-of-life marker — fires once at t=0 so `make simulate` shows
  // visible evidence the monitor_bfm elaborated and is alive.
  initial begin
    $display("[%0t] EP_MONITOR_BFM : Monitor BFM Started - Capturing link activity", $time);
  end

  task wait_for_reset();
    @(posedge preset_n);
  endtask : wait_for_reset

  task sample_detect(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for detect state,
    //       run protocol legality checks (TS0 only at 64GT/s, EC field progression, ...)
  endtask

  task sample_polling(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for polling state
  endtask

  task sample_configuration(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for configuration state
  endtask

  task sample_recovery(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for recovery state
  endtask

  task sample_l0(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for l0 state
  endtask

  task sample_l0s(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for l0s state
  endtask

  task sample_l1(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for l1 state
  endtask

endinterface : pcie_phy_ep_monitor_bfm

`endif
