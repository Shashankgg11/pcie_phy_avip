`ifndef PCIE_PHY_IF_INCLUDED_
`define PCIE_PHY_IF_INCLUDED_
 
// Import pcie_phy_pkg
import pcie_phy_pkg::*;
 
//--------------------------------------------------------------------------------------------
// Interface: pcie_phy_if
// Declaration of pin-level signals for the PCIe Gen6 PHY link (RC <-> EP direct-connect)
//--------------------------------------------------------------------------------------------
 
interface pcie_phy_if #(parameter int NUM_LANES = ACTIVE_LANES) (input refclk, input perst_n);
  //RC -> EP direction
  logic [7:0] rc_tx_symbol              [NUM_LANES];
  logic       rc_tx_symbol_k            [NUM_LANES]; // 1 = K-character (control), 0 = D-character (data)
  logic       rc_tx_electrical_idle     [NUM_LANES];
  //EP -> RC direction
  logic [7:0] ep_tx_symbol              [NUM_LANES];
  logic       ep_tx_symbol_k            [NUM_LANES]; // 1 = K-character (control), 0 = D-character (data)
  logic       ep_tx_electrical_idle     [NUM_LANES];
  //Detect-state receiver-detect results — NOT real analog modeling.
  //Analog is out of scope for this AVIP (see RX_DETECT_ASSUMED /
  //ELECTRICAL_IDLE_EXIT_ASSUMED in pcie_phy_pkg); these pins are forced
  //by the BFM (always "present") so Detect completes immediately.
  logic       rc_rx_receiver_present     [NUM_LANES];
  logic       ep_rx_receiver_present     [NUM_LANES];
  //Electrical Idle Exit flags — same bypass rationale as above
  logic       rc_rx_electrical_idle_exit [NUM_LANES];
  logic       ep_rx_electrical_idle_exit [NUM_LANES];
 
  //-------------------------------------------------------
  // Side-band status — monitor/scoreboard visibility only,
  // never driven or read by a DUT
  //-------------------------------------------------------
  ltssm_state_e rc_ltssm_state;
  ltssm_state_e ep_ltssm_state;
  logic         rc_link_up;
  logic         ep_link_up;
 
endinterface : pcie_phy_if
`endif
