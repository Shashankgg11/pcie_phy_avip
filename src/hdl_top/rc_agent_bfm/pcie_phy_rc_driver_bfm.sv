`ifndef PCIE_PHY_RC_DRIVER_BFM_INCLUDED_
`define PCIE_PHY_RC_DRIVER_BFM_INCLUDED_

//-------------------------------------------------------
// Importing global package
//-------------------------------------------------------
import pcie_phy_pkg::*;

interface pcie_phy_rc_driver_bfm(input  logic pclk,
                                  input  logic preset_n,
                                  output logic [PCIE_MAX_LANES-1:0] TX_P,
                                  output logic [PCIE_MAX_LANES-1:0] TX_N,
                                  input  logic [PCIE_MAX_LANES-1:0] RX_P,
                                  input  logic [PCIE_MAX_LANES-1:0] RX_N
                                 );

  //-------------------------------------------------------
  // Importing UVM Package
  //-------------------------------------------------------
  import uvm_pkg::*;
  import pcie_phy_pkg::*;
  import pcie_phy_rc_pkg::*;

  string name = "PCIE_PHY_RC_DRIVER_BFM";


  //RC configuration 
  pcie_phy_rc_agent_config rc_agent_cfg_h;

  initial begin
    `uvm_info(name, $sformatf(name), UVM_LOW)
  end


  clocking rcCb @(posedge pclk);
    default input #1step output #0;
    output TX_P, TX_N;
    input  RX_P, RX_N, preset_n;
  endclocking

  //-------------------------------------------------------
  // Local TX-side variable
  //-------------------------------------------------------
  pcie_gen_e   current_speed;
  bit [7:0]    configured_link_number;
  bit [7:0]    configured_lane_number [0:PCIE_MAX_LANES-1];
  int unsigned ts1_tx_count;
  int unsigned ts2_tx_count_complete;
  int unsigned idle_tx_count;

  //Each active lane's OWN running disparity for its 8b/10b encoder - a per-lane property,
  running_disparity_e lane_disparity [0:PCIE_MAX_LANES-1];

  //Each active lane's OWN running disparity for its 8b/10b DECODER (RX side).
  //ADDED - required for receive_ts below, RC previously had no RX capability at all.
  running_disparity_e rx_lane_disparity [0:PCIE_MAX_LANES-1];

  //-------------------------------------------------------
  // ADDED - LTSSM state-tracking variables. Kept as persistent module-level vars
  // (not task outputs) to match the convention already used by run_polling_active /
  // run_polling_configuration below (current_polling_substate/next_polling_substate).
  //-------------------------------------------------------
  ltssm_state_e      current_state;
  ltssm_state_e      next_state;
  detect_substate_e  current_detect_substate;
  detect_substate_e  next_detect_substate;
  polling_substate_e current_polling_substate;
  polling_substate_e next_polling_substate;
  config_substate_e  current_config_substate;
  config_substate_e  next_config_substate;

  //ADDED - referenced by the pre-existing Polling tasks below but never declared
  //in the version you shared. NOTE: your Polling code also never increments these
  //anywhere - that gap is pre-existing and left untouched here (out of scope for
  //"add missing states"; flag it to your teammate separately).
  int unsigned ts1_rx_count;
  int unsigned ts2_rx_count;

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
    rcCb.TX_P           <= '0;
    rcCb.TX_N           <= '0;
    foreach (configured_lane_number[l]) configured_lane_number[l] = PAD_SYMBOL;
    foreach (lane_disparity[l]) lane_disparity[l] = rc_agent_cfg_h.initial_disparity;
    foreach (rx_lane_disparity[l]) rx_lane_disparity[l] = rc_agent_cfg_h.initial_disparity;
    configured_link_number = PAD_SYMBOL;
    current_speed          = GEN1;
    ts1_tx_count             = 0;
    ts2_tx_count_complete    = 0;
    idle_tx_count            = 0;
    ts1_rx_count             = 0;
    ts2_rx_count             = 0;
  endtask : default_values



  //-------------------------------------------------------
  // Function: encode_8b10b_symbol
  // It takes byte value and running disparity from the pkg
  // is_k_code selects the special-case K-code pairs vs the generic D-code tables
  //-------------------------------------------------------
  function automatic bit [9:0] encode_8b10b_symbol(input bit [7:0] byte_val,
                                                     input bit is_k_code,
                                                     input running_disparity_e cur_rd);
    if (is_k_code) begin
      case (byte_val)
        COM_SYMBOL: encode_8b10b_symbol = (cur_rd == RD_MINUS) ? K_COM_N : K_COM_P;
        PAD_SYMBOL: encode_8b10b_symbol = (cur_rd == RD_MINUS) ? K_PAD_N : K_PAD_P;
        SKP_SYMBOL: encode_8b10b_symbol = (cur_rd == RD_MINUS) ? K_SKP_N : K_SKP_P;
        STP_TOKEN:  encode_8b10b_symbol = (cur_rd == RD_MINUS) ? K_STP_N : K_STP_P;
        SDP_TOKEN:  encode_8b10b_symbol = (cur_rd == RD_MINUS) ? K_SDP_N : K_SDP_P;
        END_TOKEN:  encode_8b10b_symbol = (cur_rd == RD_MINUS) ? K_END_N : K_END_P;
        EDB_TOKEN:  encode_8b10b_symbol = (cur_rd == RD_MINUS) ? K_EDB_N : K_EDB_P;
        EIE_SYM:    encode_8b10b_symbol = (cur_rd == RD_MINUS) ? K_EIE_N : K_EIE_P;
        default:    encode_8b10b_symbol = (cur_rd == RD_MINUS) ? D_NEG_DISP[byte_val]
                                                                 : D_POS_DISP[byte_val];
      endcase
    end
    else begin
      encode_8b10b_symbol = (cur_rd == RD_MINUS) ? D_NEG_DISP[byte_val] : D_POS_DISP[byte_val];
    end
  endfunction : encode_8b10b_symbol

  //-------------------------------------------------------
  // Function: decode_8b10b_symbol
  // ADDED (ported from EP driver_bfm). Inverse of encode_8b10b_symbol - checks named
  // K-codes first (both disparity variants), then falls back to a reverse lookup
  // against D_POS_DISP/D_NEG_DISP. valid=0 signals a real 8b/10b coding violation.
  //-------------------------------------------------------
  function automatic void decode_8b10b_symbol(input  bit [9:0] encoded_symbol,
                                               input  running_disparity_e cur_rd,
                                               output bit [7:0] byte_val,
                                               output bit       is_k_code,
                                               output bit       valid);
    valid     = 1'b1;
    is_k_code = 1'b0;

    if (encoded_symbol inside {K_COM_P, K_COM_N}) begin
      byte_val = COM_SYMBOL; is_k_code = 1'b1;
    end
    else if (encoded_symbol inside {K_PAD_P, K_PAD_N}) begin
      byte_val = PAD_SYMBOL; is_k_code = 1'b1;
    end
    else if (encoded_symbol inside {K_SKP_P, K_SKP_N}) begin
      byte_val = SKP_SYMBOL; is_k_code = 1'b1;
    end
    else if (encoded_symbol inside {K_STP_P, K_STP_N}) begin
      byte_val = STP_TOKEN; is_k_code = 1'b1;
    end
    else if (encoded_symbol inside {K_SDP_P, K_SDP_N}) begin
      byte_val = SDP_TOKEN; is_k_code = 1'b1;
    end
    else if (encoded_symbol inside {K_END_P, K_END_N}) begin
      byte_val = END_TOKEN; is_k_code = 1'b1;
    end
    else if (encoded_symbol inside {K_EDB_P, K_EDB_N}) begin
      byte_val = EDB_TOKEN; is_k_code = 1'b1;
    end
    else if (encoded_symbol inside {K_EIE_P, K_EIE_N}) begin
      byte_val = EIE_SYM; is_k_code = 1'b1;
    end
    else begin
      bit found;
      found = 1'b0;
      for (int b = 0; b < 256; b++) begin
        if (D_POS_DISP[b] == encoded_symbol || D_NEG_DISP[b] == encoded_symbol) begin
          byte_val = b[7:0];
          found    = 1'b1;
        end
      end
      if (!found) begin
        byte_val = '0;
        valid    = 1'b0;
      end
    end
  endfunction : decode_8b10b_symbol

  //-------------------------------------------------------
  // Function: next_running_disparity
  // Standard 8b/10b running-disparity update rule: count 1s in the just-sent 10-bit symbol;
  // more 1s -> next symbol is RD_PLUS; more 0s -> RD_MINUS; exactly balanced (5 and 5) ->
  // disparity carries over unchanged.
  //-------------------------------------------------------
  function automatic running_disparity_e next_running_disparity(input bit [9:0] encoded_symbol,
                                                                  input running_disparity_e cur_rd);
    int ones;
    ones = 0;
    for (int i = 0; i < 10; i++) begin
      if (encoded_symbol[i]) ones++;
    end
    if (ones > 5)      next_running_disparity = RD_PLUS;
    else if (ones < 5) next_running_disparity = RD_MINUS;
    else               next_running_disparity = cur_rd;
  endfunction : next_running_disparity

  //-------------------------------------------------------
  // Task: build_ts_bytes
  //  16-symbol TS content. Serialization/encoding happens entirely
  //-------------------------------------------------------
  task automatic build_ts_bytes(input os_type_e   ts_id,
                                 input bit [7:0]   link_no,
                                 input bit [7:0]   lane_no,
                                 input bit         speed_change_req,
         input bit autonomous_change,
         input bit[1:0] elbc,
         input bit no_scrambling,
         input bit loopback,
         input bit disable_link,
         input bit hot_reset,
                                 output ts_ordered_set_bytes_t bytes);
    sym4_data_rate_t     sym4;
    sym5_training_ctrl_t sym5;
    bit [7:0]            id_byte;

    sym4.speed_change        = speed_change_req;
    sym4.autonomous_change   = autonomous_change;
    sym4.speed_32gts         = (rc_agent_cfg_h.target_link_speed >= GEN5);
    sym4.speed_16gts         = (rc_agent_cfg_h.target_link_speed >= GEN4);
    sym4.speed_8gts          = (rc_agent_cfg_h.target_link_speed >= GEN3);
    sym4.speed_5gts          = (rc_agent_cfg_h.target_link_speed >= GEN2);
    sym4.speed_2p5gts        = 1'b1;
    sym4.flit_mode_supported = rc_agent_cfg_h.flit_mode_capable;

    sym5.reserved_7   = 1'b0;
    sym5.elbc_hi       = elbc[1];
    sym5.elbc_lo       = elbc[0];
    sym5.no_scrambling = no_scrambling;
    sym5.reserved_3    = 1'b0;
    sym5.loopback      = loopback;
    sym5.disable_link  = disable_link;
    sym5.hot_reset     = hot_reset;

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
  // Builds one TS (via build_ts_bytes, then for EACH of its 16 symbols: encodes
  // that symbol per-lane (own disparity, own lane-number where applicable), and serializes the resulting 10-bit codes out bit-by-bit across all
  // active lanes 
  //-------------------------------------------------------
  task automatic drive_ts(input os_type_e ts_id, input bit [7:0] link_no, input bit [7:0] lane_no,
                           input bit speed_change_req, 
         input bit autonomous_change,
               input bit[1:0] elbc,
         input bit no_scrambling,
          input bit loopback,
         input bit disable_link,
         input bit hot_reset,
input bit lane_no_per_lane);
    ts_ordered_set_bytes_t bytes;
    bit [7:0] sym_array   [0:TS_OS_LENGTH-1];
    bit       is_k_array  [0:TS_OS_LENGTH-1];
    bit [9:0] encoded     [0:PCIE_MAX_LANES-1];

    build_ts_bytes(ts_id, link_no, lane_no, speed_change_req,autonomous_change,elbc,no_scrambling,loopback,disable_link,hot_reset,bytes);

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
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
        bit [7:0] this_byte;
        this_byte = (s == 2) ? (lane_no_per_lane ? configured_lane_number[l] : lane_no)
                              : sym_array[s];
        encoded[l] = encode_8b10b_symbol(this_byte, is_k_array[s], lane_disparity[l]);
        lane_disparity[l] = next_running_disparity(encoded[l], lane_disparity[l]);
      end


      //Serialize this symbol-time's 10 bits across all active lanes, bit-aligned: every
      //lane's bit b goes out on the same clock edge. 
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
        rcCb.TX_P <= tx_p_bits;
        rcCb.TX_N <= tx_n_bits;
      end
    end
  endtask : drive_ts

  //-------------------------------------------------------
  // Task: receive_ts
  // ADDED (ported from EP driver_bfm). RX mirror of drive_ts - samples RX_P/RX_N for
  // one TS's worth of clock edges (160), decodes each symbol-time per-lane with its
  // own RX running disparity. Symbol 2 (Lane Number) is returned separately via
  // rx_lane_number[] since it is genuinely per-lane. Lane 0 is authoritative for the
  // lane-uniform symbols. Required for the newly-added Detect/Linkwidth tasks below,
  // and for the ts1_rx_count/ts2_rx_count your own Polling code already references.
  //-------------------------------------------------------
  task automatic receive_ts(output ts_ordered_set_bytes_t bytes,
                             output bit [7:0]              rx_lane_number [0:PCIE_MAX_LANES-1],
                             output bit                    valid);
    bit [7:0] sym_array  [0:TS_OS_LENGTH-1];
    bit       is_k_array [0:TS_OS_LENGTH-1];

    valid = 1'b1;

    for (int s = 0; s < TS_OS_LENGTH; s++) begin
      bit [9:0] rx_encoded [0:PCIE_MAX_LANES-1];

      for (int b = 0; b < 10; b++) begin
        @(rcCb);
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          rx_encoded[l][b] = rcCb.RX_P[l];
      end

      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
        bit [7:0] decoded_byte;
        bit       decoded_is_k;
        bit       decoded_valid;

        decode_8b10b_symbol(rx_encoded[l], rx_lane_disparity[l],
                             decoded_byte, decoded_is_k, decoded_valid);
        rx_lane_disparity[l] = next_running_disparity(rx_encoded[l], rx_lane_disparity[l]);
        if (!decoded_valid) valid = 1'b0;

        if (s == 2) begin
          rx_lane_number[l] = decoded_byte;
        end
        else if (l == 0) begin
          sym_array[s]  = decoded_byte;
          is_k_array[s] = decoded_is_k;
        end
      end
    end

    bytes.sym0_com           = sym_array[0];
    bytes.sym1_link_number   = sym_array[1];
    bytes.sym2_lane_number   = rx_lane_number[0];
    bytes.sym3_n_fts         = sym_array[3];
    bytes.sym4_data_rate_id  = sym4_data_rate_t'(sym_array[4]);
    bytes.sym5_training_ctrl = sym5_training_ctrl_t'(sym_array[5]);
    for (int i = 0; i < 10; i++) bytes.sym6_15_identifier[i] = sym_array[6+i];

    if (sym_array[0] != COM_SYMBOL || !is_k_array[0]) valid = 1'b0;
  endtask : receive_ts

  //-------------------------------------------------------
  // Task: drive_idle
  // Same encode-then-serialize path as drive_ts, but for the single repeated Idle (D0.0)
  //-------------------------------------------------------
  task automatic drive_idle();
    bit [9:0] encoded [0:PCIE_MAX_LANES-1];

    for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
      encoded[l] = encode_8b10b_symbol(IDLE_SYMBOL, 1'b0, lane_disparity[l]); //D0.0 - D-code
      lane_disparity[l] = next_running_disparity(encoded[l], lane_disparity[l]);
    end


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
      rcCb.TX_P <= tx_p_bits;
      rcCb.TX_N <= tx_n_bits;
    end
  endtask : drive_idle

  //-------------------------------------------------------
  // ADDED - Task: run_detect_quiet
  // Ported from EP, rewritten in RC's own persistent-state-variable convention
  // (current_state/next_state) instead of EP's output-argument style, to stay
  // consistent with the run_polling_active/run_polling_configuration tasks already
  // in this file.
  //-------------------------------------------------------
  task automatic run_detect_quiet();
    `uvm_info(name, "Entering Detect.Quiet", UVM_MEDIUM)

    current_state           = DETECT_ST;
    current_detect_substate = DETECT_QUIET;

    rcCb.TX_P <= '0;
    rcCb.TX_N <= '0;

    repeat (rc_agent_cfg_h.detect_timeout_cycles) begin
      @(rcCb);
      if (check_electrical_idle_exit_any_lane()) begin
        `uvm_info(name, "Electrical Idle Exit detected - moving to Detect.Active", UVM_HIGH)
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_ACTIVE;
        return;
      end
    end

    `uvm_info(name, "Detect.Quiet timeout expired - moving to Detect.Active", UVM_HIGH)
    next_state           = DETECT_ST;
    next_detect_substate = DETECT_ACTIVE;
  endtask : run_detect_quiet

  //-------------------------------------------------------
  // ADDED - Task: run_detect_active
  //-------------------------------------------------------
  task automatic run_detect_active();
    bit [PCIE_MAX_LANES-1:0] pass1_mask;
    bit [PCIE_MAX_LANES-1:0] pass2_mask;
    bit [PCIE_MAX_LANES-1:0] expected_mask;

    `uvm_info(name, "Entering Detect.Active", UVM_MEDIUM)

    current_state           = DETECT_ST;
    current_detect_substate = DETECT_ACTIVE;

    expected_mask = '0;
    for (int lane = 0; lane < rc_agent_cfg_h.active_lanes; lane++)
      expected_mask[lane] = 1'b1;

    pass1_mask = perform_receiver_detection_all_lanes();

    if (pass1_mask == '0) begin
      `uvm_info(name, "No receiver detected - returning to Detect.Quiet", UVM_HIGH)
      next_state           = DETECT_ST;
      next_detect_substate = DETECT_QUIET;
      return;
    end

    if (pass1_mask == expected_mask) begin
      `uvm_info(name, "Receiver detected on all active lanes - moving to Polling", UVM_HIGH)
      next_state = POLLING_ST;
      return;
    end

    `uvm_info(name, "Partial receiver detection - retrying Receiver Detection", UVM_HIGH)
    repeat (rc_agent_cfg_h.detect_timeout_cycles) @(rcCb);

    pass2_mask = perform_receiver_detection_all_lanes();

    if (pass2_mask == expected_mask) begin
      `uvm_info(name, "Receiver detected on retry - moving to Polling", UVM_HIGH)
      next_state = POLLING_ST;
    end
    else begin
      `uvm_info(name, "Receiver detection failed - returning to Detect.Quiet", UVM_HIGH)
      next_state           = DETECT_ST;
      next_detect_substate = DETECT_QUIET;
    end
  endtask : run_detect_active

  //-------------------------------------------------------
  // ADDED - Function: check_electrical_idle_exit_any_lane
  // Ported from EP - electrical part, so taking the same assumption
  //-------------------------------------------------------
  function automatic bit check_electrical_idle_exit_any_lane();
    return ELECTRICAL_IDLE_EXIT_ASSUMED;
  endfunction : check_electrical_idle_exit_any_lane

  //-------------------------------------------------------
  // ADDED - Function: perform_receiver_detection_all_lanes
  //-------------------------------------------------------
  function automatic bit [PCIE_MAX_LANES-1:0] perform_receiver_detection_all_lanes();
    bit [PCIE_MAX_LANES-1:0] lane_mask;

    lane_mask = '0;

    if (!RX_DETECT_ASSUMED) return lane_mask;

    for (int lane = 0; lane < rc_agent_cfg_h.active_lanes; lane++) begin
      lane_mask[lane] = 1'b1;
    end

    `uvm_info(name, $sformatf("Receiver detected on %0d active lane(s). Mask = %0h",
                               rc_agent_cfg_h.active_lanes, lane_mask), UVM_HIGH)

    return lane_mask;
  endfunction : perform_receiver_detection_all_lanes

  //-------------------------------------------------------
  // ADDED - Task: run_linkwidth_start
  // Spec 4.2.7.3.1 (Downstream Lanes) - RC is the PROPOSER here, opposite role from
  // EP's version: RC picks Link=0x00 immediately and transmits it from entry, then
  // waits to see EP echo that same Link Number back (Lane still PAD) for 2
  // consecutive TS1s before advancing. TX/RX run concurrently via fork/join_none,
  // same full-duplex structure used in EP's version.
  //-------------------------------------------------------
  task automatic run_linkwidth_start();
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_link_match_cnt;
    int unsigned            ts_attempt_cnt;

    `uvm_info(name, "Entering Configuration.Linkwidth.Start", UVM_MEDIUM)

    current_state           = CONFIG_ST;
    current_config_substate = CFG_LINKWIDTH_START;

    consec_link_match_cnt  = 0;
    ts_attempt_cnt          = 0;
    configured_link_number  = 8'h00;  //RC (Downstream) proposes Link=0x00 immediately

    fork
      forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL,
                        1'b0, 1'b0, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;
      ts1_rx_count++;

      if (rx_valid && rx_bytes.sym6_15_identifier[0] == TS1_ID_BYTE &&
          rx_bytes.sym1_link_number == configured_link_number &&
          rx_lane_number[0] == PAD_SYMBOL) begin
        consec_link_match_cnt++;
      end
      else begin
        consec_link_match_cnt = 0;
      end

      if (consec_link_match_cnt >= CONSEC_TS_REQUIRED) begin
        `uvm_info(name, "Configuration.Linkwidth.Start complete - advancing to Linkwidth.Accept", UVM_HIGH)
        disable fork;
        next_state             = CONFIG_ST;
        next_config_substate   = CFG_LINKWIDTH_ACCEPT;
        return;
      end

      if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_info(name, "Configuration.Linkwidth.Start timeout - returning to Detect", UVM_HIGH)
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_linkwidth_start

  //-------------------------------------------------------
  // ADDED - Task: run_linkwidth_accept
  // Spec 4.2.7.3.2 (Downstream Lanes) - RC is the ASSIGNER here: picks sequential
  // Lane Numbers 0..n-1 for its own active lanes and transmits them. Exit condition
  // is seeing EP echo back a full, non-PAD Lane Number group. RC does NOT need
  // lane-reversal detection - that is EP's responsibility only, since RC defines
  // the canonical numbering everyone else measures against.
  //-------------------------------------------------------
  task automatic run_linkwidth_accept();
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            ts_attempt_cnt;

    `uvm_info(name, "Entering Configuration.Linkwidth.Accept", UVM_MEDIUM)

    current_state           = CONFIG_ST;
    current_config_substate = CFG_LINKWIDTH_ACCEPT;
    ts_attempt_cnt = 0;

    for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
      configured_lane_number[l] = l[7:0];

    fork
      forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL,
                        1'b0, 1'b0, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
    join_none

    forever begin
      bit valid_group;

      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;
      ts1_rx_count++;

      if (rx_valid) begin
        valid_group = 1'b1;
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] == PAD_SYMBOL) valid_group = 1'b0;

        if (valid_group) begin
          `uvm_info(name, "Valid Lane group echoed by EP - advancing to Lanenum.Wait", UVM_HIGH)
          disable fork;
          next_state             = CONFIG_ST;
          next_config_substate   = CFG_LANENUM_WAIT;
          return;
        end
      end

      if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_info(name, "Configuration.Linkwidth.Accept timeout - returning to Detect", UVM_HIGH)
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_linkwidth_accept

  //--------------------------------------------------------------------------------------------------------------------------------- 
  //    POLLING ACTIVE           
  //---------------------------------------------------------------------------------------------------------------------------------
  task automatic run_polling_active();

  time start_time;
  `uvm_info(name, "Entering Polling.Active", UVM_MEDIUM)

  current_state = POLLING_ST;
  current_polling_substate = POLLING_ACTIVE;


  ts1_tx_count = 0;

  start_time   = $time;

  forever begin
    drive_ts(OS_TS1,PAD_SYMBOL,PAD_SYMBOL,1'b1,1'b0,2'b11,1'b0,1'b0,1'b0,1'b0,1'b1);
    ts1_tx_count++;

    // Exit to Polling.Configuration
    if ((ts1_tx_count >= TS1_1024_COUNT) &&(ts1_rx_count  >= CONSEC_TS_COUNT)) begin
      `uvm_info(name,"Polling.Active completed successfully",UVM_LOW)

      next_state            = POLLING_ST;
      next_polling_substate = POLLING_CONFIG;

      // Reset for next entry
      ts1_tx_count = 0;
      ts1_rx_count = 0;

      break;
    end

    // Timeout
    if (($time - start_time) >= (POLLING_TIMEOUT_MS)) begin
      `uvm_error(name,"Polling.Active Timeout")

      next_state           = DETECT_ST;
      next_detect_substate = DETECT_QUIET;

      ts1_tx_count = 0;
      ts1_rx_count = 0;

      break;
    end
  end
endtask

//--------------------------------------------------------------------------------------------------------------------------------- 
//      POLLING CONFIGURE       
  //---------------------------------------------------------------------------------------------------------------------------------
task automatic run_polling_configuration();

  time start_time;
  current_state = POLLING_ST;
  current_polling_substate = POLLING_CONFIG;
  `uvm_info(name, "Entering Polling.Configuration", UVM_MEDIUM)

  ts2_tx_count_complete = 0;
  start_time            = $time;

  forever begin

    drive_ts(OS_TS2,PAD_SYMBOL,PAD_SYMBOL,1'b1,1'b0,2'b11,1'b0,1'b0,1'b0,1'b0,1'b1);

    // Count transmitted TS2 only after receiving first TS2
    if (ts2_rx_count > 0)
      ts2_tx_count_complete++;

    // Exit to Configuration
    if ((ts2_tx_count_complete >= MIN_TS2_TX_COMPLETE) &&
        (ts2_rx_count >= CONSEC_TS_COUNT)) begin

      `uvm_info(name,
                "Polling.Configuration completed successfully",
                UVM_LOW)
      next_state = CONFIG_ST;
      //next_polling_substate = CFG_LINKWIDTH_SATRT;

      // Reset for next entry
      ts2_tx_count_complete = 0;
      ts2_rx_count          = 0;

      break;
    end

    // Timeout
    if (($time - start_time) >= (CONFIG_TIMEOUT_MS)) begin

      `uvm_error(name,"Polling.Configuration Timeout")

      next_state = DETECT_ST;
      //next_polling_substate = DETECT_QUIET;      

      ts2_tx_count_complete = 0;
      ts2_rx_count          = 0;

      break;
    end

  end

endtask

endinterface : pcie_phy_rc_driver_bfm

`endif
