`ifndef PCIE_PHY_RC_MONITOR_BFM_INCLUDED_
`define PCIE_PHY_RC_MONITOR_BFM_INCLUDED_

import pcie_phy_globals_pkg::*;

//--------------------------------------------------------------------------------------------
// Interface: pcie_phy_rc_monitor_bfm
// Passive shadow-LTSSM monitor BFM for the Downstream Port (Root Complex).
// Samples link signals through the interface but cannot drive them.
//--------------------------------------------------------------------------------------------
interface pcie_phy_rc_monitor_bfm(input bit aclk, input bit aresetn,
                                     input [7:0] rc_tx_symbol [NUM_LANES],
                                     input        rc_tx_electrical_idle [NUM_LANES]);

  task wait_for_aresetn();
    @(posedge aresetn);
  endtask : wait_for_aresetn

  task sample_detect(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for detect state,
    //       run protocol legality checks (TS0 only at 64GT/s, EC field progression, ...)
  endtask

  task sample_polling(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for polling state,
    //       run protocol legality checks (TS0 only at 64GT/s, EC field progression, ...)
  endtask

  task sample_configuration(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for configuration state,
    //       run protocol legality checks (TS0 only at 64GT/s, EC field progression, ...)
  endtask

  task sample_recovery(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for recovery state,
    //       run protocol legality checks (TS0 only at 64GT/s, EC field progression, ...)
  endtask

  task sample_l0(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for l0 state,
    //       run protocol legality checks (TS0 only at 64GT/s, EC field progression, ...)
  endtask

  task sample_l0s(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for l0s state,
    //       run protocol legality checks (TS0 only at 64GT/s, EC field progression, ...)
  endtask

  task sample_l1(output ltssm_state_e shadow_state);
    // TODO: decode symbols, update shadow LTSSM for l1 state,
    //       run protocol legality checks (TS0 only at 64GT/s, EC field progression, ...)
  endtask

endinterface : pcie_phy_rc_monitor_bfm

`endif
