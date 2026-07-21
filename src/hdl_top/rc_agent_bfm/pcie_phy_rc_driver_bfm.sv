
`ifndef PCIE_PHY_RC_DRIVER_BFM_INCLUDED_
`define PCIE_PHY_RC_DRIVER_BFM_INCLUDED_
 
//-------------------------------------------------------
// Importing global package
//-------------------------------------------------------
import pcie_phy_pkg::*;
 
interface pcie_phy_rc_driver_bfm(input  logic pclk,
                                  input  logic preset_n,
                                  //TX side (RC transmitting) - true differential serial,
                                  //one bit per lane per clock (10 clocks per encoded symbol).
                                  //Packed vectors, one bit per lane - see note above.
                                  output logic [PCIE_MAX_LANES-1:0] pipe_tx_p,
                                  output logic [PCIE_MAX_LANES-1:0] pipe_tx_n,
                                  output logic        pipe_tx_data_valid, //this lane is
                                                                          //actively driving
                                                                          //(vs undriven/reset)
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
 
  string name = "PCIE_PHY_RC_DRIVER_BFM";
 
  //Handle back to the HVL driver_proxy - set externally once the proxy retrieves this BFM
  pcie_phy_rc_driver_proxy rc_drv_proxy_h;
 
  //RC configuration - set externally (normally by the proxy right after retrieving this BFM)
  pcie_phy_rc_agent_config rc_agent_cfg_h;
 
  initial begin
    `uvm_info(name, $sformatf(name), UVM_LOW)
  end
 
  //-------------------------------------------------------
CLOCKING BLOCK
  //-------------------------------------------------------
  clocking rcCb @(posedge pclk);
    default input #1step output #0;
    output pipe_tx_p, pipe_tx_n, pipe_tx_data_valid, pipe_rate, phy_link_up, ltssm_status,
           transfer_mode;
    input  preset_n;
  endclocking
 
  //-------------------------------------------------------
  // Local TX-side state kept across the whole run_ltssm() flow.
  //-------------------------------------------------------
  pcie_gen_e   current_speed;
  bit [7:0]    configured_link_number;
  bit [7:0]    configured_lane_number [0:PCIE_MAX_LANES-1];
  int unsigned ts1_tx_count;
  int unsigned ts2_tx_count_complete;
  int unsigned idle_tx_count;
 
  //Each active lane's OWN running disparity for its 8b/10b encoder - a per-lane property,
  //updated symbol by symbol as this BFM transmits. Reset to rc_agent_cfg_h.initial_disparity.
  running_disparity_e lane_disparity [0:PCIE_MAX_LANES-1];
 
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
    rcCb.pipe_tx_p           <= '0;
    rcCb.pipe_tx_n           <= '0;
    foreach (configured_lane_number[l]) configured_lane_number[l] = PAD_SYMBOL;
    foreach (lane_disparity[l]) lane_disparity[l] = rc_agent_cfg_h.initial_disparity;
    configured_link_number = PAD_SYMBOL;
    current_speed          = GEN1;
    ts1_tx_count             = 0;
    ts2_tx_count_complete    = 0;
    idle_tx_count            = 0;
  endtask : default_values
 


 
  //-------------------------------------------------------
  // Task: build_ts_bytes
  // UNCHANGED from the parallel-bus version - still a pure TX-side computation producing
  // the logical (pre-encoding) 16-symbol TS content. Serialization/encoding happens entirely
  // downstream of this, in drive_ts() below.
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
 
  //-------------------------------------------------------
  // Task: drive_ts
  //-------------------------------------------------------
  task automatic drive_ts(input os_type_e ts_id, input bit [7:0] link_no, input bit [7:0] lane_no,
                           input bit speed_change_req, input bit lane_no_per_lane);
    ts_ordered_set_bytes_t bytes;
    bit [7:0] sym_array   [0:TS_OS_LENGTH-1];
    bit       is_k_array  [0:TS_OS_LENGTH-1];
    bit [9:0] encoded     [0:PCIE_MAX_LANES-1];
 
    build_ts_bytes(ts_id, link_no, lane_no, speed_change_req, bytes);
 
    sym_array[0] = bytes.sym0_com;           is_k_array[0] = 1'b1; //COM is the only K-code
    sym_array[1] = bytes.sym1_link_number;   is_k_array[1] = 1'b0;
    //sym_array[2]/is_k_array[2] unused - symbol 2 (lane number) is built per-lane below
    sym_array[3] = bytes.sym3_n_fts;         is_k_array[3] = 1'b0;
    sym_array[4] = bytes.sym4_data_rate_id;  is_k_array[4] = 1'b0;
    sym_array[5] = bytes.sym5_training_ctrl; is_k_array[5] = 1'b0;
    for (int i = 0; i < 10; i++) begin
      sym_array[6+i] = bytes.sym6_15_identifier[i];
      is_k_array[6+i] = 1'b0; //TS1/TS2 identifier bytes are D-codes, not K-codes
    end
 
    for (int s = 0; s < TS_OS_LENGTH; s++) begin
      //Encode this symbol-time ONCE per lane (own byte for s==2, own running disparity),
      //advancing each lane's disparity for the next symbol-time
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
        bit [7:0] this_byte;
        this_byte = (s == 2) ? (lane_no_per_lane ? configured_lane_number[l] : lane_no)
                              : sym_array[s];
        //have to build the encoder and store the the current running disparity
      end
 
      rcCb.pipe_tx_data_valid <= 1'b1;
 
      //Serialize this symbol-time's 10 bits across all active lanes, bit-aligned: every
           for (int b = 0; b < 10; b++) begin
        logic [PCIE_MAX_LANES-1:0] tx_p_bits, tx_n_bits;
        @(rcCb);
        tx_p_bits = '0;
        tx_n_bits = '0;
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
          if (encoded[l][b]) begin
            tx_p_bits[l] = 1'b1;
            tx_n_bits[l] = 1'b0;
          end
          else begin
            tx_p_bits[l] = 1'b0;
            tx_n_bits[l] = 1'b1;
          end
        end
        rcCb.pipe_tx_p <= tx_p_bits;
        rcCb.pipe_tx_n <= tx_n_bits;
      end
    end
  endtask : drive_ts
 
  
endinterface : pcie_phy_rc_driver_bfm
 
`endif

