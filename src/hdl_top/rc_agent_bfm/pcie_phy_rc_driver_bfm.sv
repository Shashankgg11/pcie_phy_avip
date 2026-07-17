`ifndef PCIE_PHY_RC_DRIVER_BFM_INCLUDED_

`define PCIE_PHY_RC_DRIVER_BFM_INCLUDED_
 
//-------------------------------------------------------

// Importing global package

//-------------------------------------------------------

import pcie_phy_pkg::*;
 
interface pcie_phy_rc_driver_bfm(input  logic pclk,

                                  input  logic preset_n,

                                  //TX side (RC transmitting), one byte per active lane

                                  output logic [7:0] pipe_tx_data      [0:PCIE_MAX_LANES-1],

                                  output logic        pipe_tx_data_valid,

                                  output pipe_rate_e   pipe_rate,       //logical rate REQUEST

                                  //Logical handshake / observability (driver-owned outputs)

                                  output logic        phy_link_up,

                                  output ltssm_status_t         ltssm_status,

                                  output data_transfer_mode_e   transfer_mode

                                 );
 
  //-------------------------------------------------------

  // Importing UVM Package

  //-------------------------------------------------------

  import uvm_pkg::*;
 
  //Variable: name

  string name = "PCIE_PHY_RC_DRIVER_BFM";
 
  //Handle back to the HVL driver_proxy - set externally once the proxy retrieves this BFM

  pcie_phy_rc_driver_proxy rc_drv_proxy_h;
 
  //RC configuration - set externally (normally by the proxy right after retrieving this BFM)

  pcie_phy_rc_agent_config rc_agent_cfg_h;
 
  initial begin

    `uvm_info(name, $sformatf(name), UVM_LOW)

  end
 
 
  clocking rcCb @(posedge pclk);

    default input #1step output #0;

    output pipe_tx_data_valid, pipe_rate, phy_link_up, ltssm_status, transfer_mode;

    input  preset_n;

  endclocking
 
  pcie_gen_e   current_speed;

  bit [7:0]    configured_link_number;

  bit [7:0]    configured_lane_number [0:PCIE_MAX_LANES-1];

  int unsigned ts1_tx_count;

  int unsigned ts2_tx_count_complete;

  int unsigned idle_tx_count;
 
 
  //-------------------------------------------------------

  // Task: wait_for_reset

  //-------------------------------------------------------

  task wait_for_reset();

    @(negedge preset_n);

    `uvm_info(name, "SYSTEM RESET DETECTED", UVM_HIGH)

    default_values();

    @(posedge preset_n);

    `uvm_info(name, "SYSTEM RESET DEACTIVATED", UVM_HIGH)

  endtask : wait_for_reset
 
  //-------------------------------------------------------

  // Task: default_values

  //-------------------------------------------------------

  task default_values();

    rcCb.pipe_tx_data_valid <= 1'b0;

    rcCb.phy_link_up        <= 1'b0;

    rcCb.pipe_rate           <= PIPE_RATE_GEN1;

    foreach (pipe_tx_data[l]) pipe_tx_data[l] <= '0;

    foreach (configured_lane_number[l]) configured_lane_number[l] = PAD_SYMBOL;

    configured_link_number = PAD_SYMBOL;

    current_speed          = GEN1;

    ts1_tx_count             = 0;

    ts2_tx_count_complete    = 0;

    idle_tx_count            = 0;

  endtask : default_values
 
  //=========================================================================================

  // SHARED HELPERS - build one TS Ordered Set (used by every state's driving side)

  //=========================================================================================
 
  //-------------------------------------------------------

  // Task: build_ts_bytes

  // Builds the raw wire-level symbols for one TS1/TS2. link_no/lane_no are passed in so the

  // same helper serves Polling (PAD_SYMBOL/PAD_SYMBOL) and Configuration (real numbers).

  //-------------------------------------------------------

  task automatic build_ts_bytes(input os_type_e   ts_id,

                                 input bit [7:0]   link_no,

                                 input bit [7:0]   lane_no,

                                 input bit         speed_change_req,

                                 output ts_ordered_set_bytes_t bytes);

    sym4_data_rate_t     sym4;

    sym5_training_ctrl_t sym5;

    bit [7:0]            id_byte;
 
    sym4.speed_change        = speed_change_req;

    sym4.autonomous_change   = 1'b0;

    sym4.speed_32gts         = (rc_agent_cfg_h.target_link_speed >= GEN5);

    sym4.speed_16gts         = (rc_agent_cfg_h.target_link_speed >= GEN4);

    sym4.speed_8gts          = (rc_agent_cfg_h.target_link_speed >= GEN3);

    sym4.speed_5gts          = (rc_agent_cfg_h.target_link_speed >= GEN2);

    sym4.speed_2p5gts        = 1'b1;

    sym4.flit_mode_supported = rc_agent_cfg_h.flit_mode_capable;
 
    sym5.reserved_7   = 1'b0;

    sym5.elbc_hi       = 1'b1;

    sym5.elbc_lo       = 1'b1;

    sym5.no_scrambling = 1'b0;

    sym5.reserved_3    = 1'b0;

    sym5.loopback      = 1'b0;

    sym5.disable_link  = 1'b0;

    sym5.hot_reset     = 1'b0;
 
    id_byte = (ts_id == OS_TS2) ? TS2_ID_BYTE : TS1_ID_BYTE;
 
    bytes.sym0_com           = COM_SYMBOL;

    bytes.sym1_link_number   = link_no;

    bytes.sym2_lane_number   = lane_no;

    bytes.sym3_n_fts         = rc_agent_cfg_h.ntfs;

    bytes.sym4_data_rate_id  = sym4;

    bytes.sym5_training_ctrl = sym5;

    foreach (bytes.sym6_15_identifier[i]) begin

      bytes.sym6_15_identifier[i] = id_byte;

    end

  endtask : build_ts_bytes
 
endinterface : pcie_phy_rc_driver_bfm
 
`endif
 
