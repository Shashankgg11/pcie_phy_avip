`ifndef PCIE_PHY_EP_DRIVER_BFM_INCLUDED_
`define PCIE_PHY_EP_DRIVER_BFM_INCLUDED_

//-------------------------------------------------------
// Importing global package
//-------------------------------------------------------
import pcie_phy_pkg::*;
import pcie_phy_ep_pkg::*;

interface pcie_phy_ep_driver_bfm(input  logic pclk,
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

  string name = "PCIE_PHY_EP_DRIVER_BFM";


  //EP configuration 
  pcie_phy_ep_agent_config ep_agent_cfg_h;

  initial begin
    `uvm_info(name, $sformatf(name), UVM_LOW)
  end


  clocking epCb @(posedge pclk);
    default input #1step output #0;
    output TX_P, TX_N;
    input  RX_P, RX_N, preset_n;
  endclocking

  // Local TX-side variable
  //-------------------------------------------------------
  pcie_gen_e   current_speed;
  bit [7:0]    configured_link_number;
  bit [7:0]    configured_lane_number [0:PCIE_MAX_LANES-1];
  int unsigned ts1_tx_count;
  int unsigned ts2_tx_count_complete;
  int unsigned idle_tx_count;

  //Each active lane's OWN running disparity for its 8b/10b encoder (TX side) - a
  //per-lane property, tracked independently from the RX-side disparity below.
  running_disparity_e lane_disparity [0:PCIE_MAX_LANES-1];

  //Each active lane's OWN running disparity for its 8b/10b DECODER (RX side).
  //Real 8b/10b receivers track RX disparity independently from TX disparity.
  running_disparity_e rx_lane_disparity [0:PCIE_MAX_LANES-1];

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
    epCb.TX_P           <= '0;
    epCb.TX_N           <= '0;
    foreach (configured_lane_number[l]) configured_lane_number[l] = PAD_SYMBOL;
    foreach (lane_disparity[l])    lane_disparity[l]    = ep_agent_cfg_h.initial_disparity;
    foreach (rx_lane_disparity[l]) rx_lane_disparity[l] = ep_agent_cfg_h.initial_disparity;
    configured_link_number = PAD_SYMBOL;
    current_speed          = GEN1;
    ts1_tx_count             = 0;
    ts2_tx_count_complete    = 0;
    idle_tx_count            = 0;
  endtask : default_values

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

  // Function: decode_8b10b_symbol
  // Inverse of encode_8b10b_symbol. Checks named K-codes first (both disparity
  // variants), then falls back to a reverse lookup against the same D_POS_DISP/
  // D_NEG_DISP tables the encoder uses. valid=0 signals a real 8b/10b coding
  // violation - useful hook for error-injection / link-error checks later.
  // NOTE: does not cross-check the incoming symbol's disparity against cur_rd for
  // a running-disparity error - only confirms the symbol decodes to a legal byte.
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
                                 output ts_ordered_set_bytes_t bytes);
    sym4_data_rate_t     sym4;
    sym5_training_ctrl_t sym5;
    bit [7:0]            id_byte;

    sym4.speed_change        = speed_change_req;
    sym4.autonomous_change   = 1'b0;
    sym4.speed_32gts         = (ep_agent_cfg_h.target_link_speed >= GEN5);
    sym4.speed_16gts         = (ep_agent_cfg_h.target_link_speed >= GEN4);
    sym4.speed_8gts          = (ep_agent_cfg_h.target_link_speed >= GEN3);
    sym4.speed_5gts          = (ep_agent_cfg_h.target_link_speed >= GEN2);
    sym4.speed_2p5gts        = 1'b1;
    sym4.flit_mode_supported = ep_agent_cfg_h.flit_mode_capable;

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
    bytes.sym3_n_fts         = ep_agent_cfg_h.ntfs;
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
      for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++) begin
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
        @(epCb);
        tx_p_bits = '0;
        tx_n_bits = '0;
        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++) begin
          if (encoded[l][b]) begin
            tx_p_bits[l] = 1'b1;
            tx_n_bits[l] = 1'b0;
          end
          else begin
            tx_p_bits[l] = 1'b0;
            tx_n_bits[l] = 1'b1;
          end
        end
        epCb.TX_P <= tx_p_bits;
        epCb.TX_N <= tx_n_bits;
      end
    end
  endtask : drive_ts

  //-------------------------------------------------------
  // Task: receive_ts
  // RX mirror of drive_ts: samples RX_P/RX_N for one TS's worth of clock edges
  // (16 symbols x 10 bits = 160 edges), decodes each symbol-time per-lane with its
  // own RX running disparity, and reconstructs the received TS. Symbol 2 (Lane
  // Number) is genuinely per-lane, so it's returned separately via rx_lane_number[]
  // rather than folded into the bytes struct's single sym2_lane_number field.
  // Lane 0 is treated as authoritative for the lane-uniform symbols (0,1,3,4,5,6-15).
  // LIMITATION: assumes symbol-boundary alignment is already known (no comma/
  // elastic-buffer realignment modeled) - acceptable at this logical-PHY scope.
  //-------------------------------------------------------
  task automatic receive_ts(output ts_ordered_set_bytes_t bytes,
                             output bit [7:0]              rx_lane_number [0:PCIE_MAX_LANES-1],
                             output bit                    valid);
    bit [7:0] sym_array  [0:TS_OS_LENGTH-1];
    bit       is_k_array [0:TS_OS_LENGTH-1];

    valid = 1'b1;

    for (int s = 0; s < TS_OS_LENGTH; s++) begin
      bit [9:0] rx_encoded [0:PCIE_MAX_LANES-1];

      //Sample this symbol-time's 10 bits across all active lanes, bit-aligned
      for (int b = 0; b < 10; b++) begin
        @(epCb);
        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
          rx_encoded[l][b] = epCb.RX_P[l];
      end

      //Decode this symbol-time ONCE per lane (own RX running disparity)
      for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++) begin
        bit [7:0] decoded_byte;
        bit       decoded_is_k;
        bit       decoded_valid;

        decode_8b10b_symbol(rx_encoded[l], rx_lane_disparity[l],
                             decoded_byte, decoded_is_k, decoded_valid);
        rx_lane_disparity[l] = next_running_disparity(rx_encoded[l], rx_lane_disparity[l]);
        if (!decoded_valid) valid = 1'b0;

        if (s == 2) begin
          rx_lane_number[l] = decoded_byte; //genuinely per-lane
        end
        else if (l == 0) begin
          sym_array[s]  = decoded_byte;     //lane-uniform symbols - lane 0 is authoritative
          is_k_array[s] = decoded_is_k;
        end
      end
    end

    bytes.sym0_com           = sym_array[0];
    bytes.sym1_link_number   = sym_array[1];
    bytes.sym2_lane_number   = rx_lane_number[0]; //representative value; see rx_lane_number[] for full per-lane detail
    bytes.sym3_n_fts         = sym_array[3];
    bytes.sym4_data_rate_id  = sym4_data_rate_t'(sym_array[4]);
    bytes.sym5_training_ctrl = sym5_training_ctrl_t'(sym_array[5]);
    for (int i = 0; i < 10; i++) bytes.sym6_15_identifier[i] = sym_array[6+i];

    if (sym_array[0] != COM_SYMBOL || !is_k_array[0]) valid = 1'b0; //must start with COM
  endtask : receive_ts

  //-------------------------------------------------------
  // Task: drive_idle
  // Same encode-then-serialize path as drive_ts, but for the single repeated Idle (D0.0)
  //-------------------------------------------------------
  task automatic drive_idle();
    bit [9:0] encoded [0:PCIE_MAX_LANES-1];

    for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++) begin
      encoded[l] = encode_8b10b_symbol(IDLE_SYMBOL, 1'b0, lane_disparity[l]); //D0.0 - D-code
      lane_disparity[l] = next_running_disparity(encoded[l], lane_disparity[l]);
    end

    for (int b = 0; b < 10; b++) begin
      logic [PCIE_MAX_LANES-1:0] tx_p_bits, tx_n_bits;
      @(epCb);
      tx_p_bits = '0;
      tx_n_bits = '0;
      for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++) begin
        if (encoded[l][b]) begin
          tx_p_bits[l] = 1'b1;
          tx_n_bits[l] = 1'b0;
        end
        else begin
          tx_p_bits[l] = 1'b0;
          tx_n_bits[l] = 1'b1;
        end
      end
      epCb.TX_P <= tx_p_bits;
      epCb.TX_N <= tx_n_bits;
    end
  endtask : drive_idle

// Task: run_detect_quiet
  // Detect has no Ordered-Set traffic, so this still relies on
  // ELECTRICAL_IDLE_EXIT_ASSUMED (pcie_phy_pkg) rather than real RX decode - real
  // Electrical Idle detection is an analog/voltage concept, out of this VIP's scope.
  //-------------------------------------------------------
  task run_detect_quiet(output detect_substate_e next_substate);

    `uvm_info(name, "Entering Detect.Quiet", UVM_MEDIUM)

    // Keep transmitter in Electrical Idle
    epCb.TX_P <= '0;
    epCb.TX_N <= '0;

    repeat (ep_agent_cfg_h.detect_timeout_cycles) begin

      @(epCb);

      if (check_electrical_idle_exit_any_lane()) begin
        `uvm_info(name, "Electrical Idle Exit detected - moving to Detect.Active", UVM_HIGH)
        next_substate = DETECT_ACTIVE;
        return;
      end

    end

    `uvm_info(name, "Detect.Quiet timeout expired - moving to Detect.Active",UVM_HIGH)

    next_substate = DETECT_ACTIVE;

  endtask : run_detect_quiet

  // Task: run_detect_active
  //-------------------------------------------------------
  task run_detect_active(output ltssm_state_e next_state);

    bit [PCIE_MAX_LANES-1:0] pass1_mask;
    bit [PCIE_MAX_LANES-1:0] pass2_mask;
    bit [PCIE_MAX_LANES-1:0] expected_mask;

    `uvm_info(name, "Entering Detect.Active", UVM_MEDIUM)

    expected_mask = '0;
    for (int lane = 0; lane < ep_agent_cfg_h.active_lanes; lane++)
      expected_mask[lane] = 1'b1;

    // First Receiver Detection
    pass1_mask = perform_receiver_detection_all_lanes();

    if (pass1_mask == '0) begin
      `uvm_info(name, "No receiver detected - returning to Detect.Quiet",UVM_HIGH)
      next_state = DETECT_ST;
      return;
    end

    if (pass1_mask == expected_mask) begin
      `uvm_info(name, "Receiver detected on all active lanes - moving to Polling",UVM_HIGH)
      next_state = POLLING_ST;
      return;
    end

    `uvm_info(name, "Partial receiver detection - retrying Receiver Detection", UVM_HIGH)

    repeat (ep_agent_cfg_h.detect_timeout_cycles)
      @(epCb);

    // Second Receiver Detection
    pass2_mask = perform_receiver_detection_all_lanes();

    if (pass2_mask == expected_mask) begin
      `uvm_info(name, "Receiver detected on retry - moving to Polling", UVM_HIGH)
      next_state = POLLING_ST;
    end
    else begin
      `uvm_info(name, "Receiver detection failed - returning to Detect.Quiet", UVM_HIGH)
      next_state = DETECT_ST;
    end

  endtask : run_detect_active

  // check_electrical_idle_exit_any_lane
  // electrical part so taking assumptions 
  //-------------------------------------------------------
  function automatic bit check_electrical_idle_exit_any_lane();
    return ELECTRICAL_IDLE_EXIT_ASSUMED;
  endfunction : check_electrical_idle_exit_any_lane

  // Function: perform_receiver_detection_all_lanes
  //-------------------------------------------------------
  function automatic bit [PCIE_MAX_LANES-1:0] perform_receiver_detection_all_lanes();

    bit [PCIE_MAX_LANES-1:0] lane_mask;

    lane_mask = '0;

    if(!RX_DETECT_ASSUMED) return lane_mask;

    for(int lane = 0; lane < ep_agent_cfg_h.active_lanes; lane++)begin
      lane_mask[lane] = 1'b1;
    end

    `uvm_info(name, $sformatf("Receiver detected on %0d active lane(s). Mask = %0h",ep_agent_cfg_h.active_lanes, lane_mask), UVM_HIGH)

    return lane_mask;

  endfunction : perform_receiver_detection_all_lanes

  // Task: run_linkwidth_start
  //TX and RX run as CONCURRENT processes
  // fork join_none models full duplex behavior
  // Phase A - link_latched==0 TX sends Link=PAD/Lane=PAD while RX watches for RC's
  //          proposed (non-PAD) Link Number to appear
  // Phase B - link_latched==1 TX echoes the latched Link Number, Lane still PAD,
  //          while RX watches for RC to reflect that SAME Link Number back with
  //          Lane still PAD, 2 consecutive times - the real spec exit condition
  
  task automatic run_linkwidth_start(output config_substate_e next_config_substate,
                                      output ltssm_state_e     next_state);
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0] rx_lane_number [0:PCIE_MAX_LANES-1];
    bit rx_valid;
    int unsigned consec_link_match_cnt;
    int unsigned ts_attempt_cnt;
    bit link_latched;

    `uvm_info(name, "Entering Configuration.Linkwidth.Start", UVM_MEDIUM)

    consec_link_match_cnt  = 0;
    ts_attempt_cnt          = 0;
    link_latched            = 1'b0;
    configured_link_number  = PAD_SYMBOL;

    fork
      forever drive_ts(OS_TS1, link_latched ? configured_link_number : PAD_SYMBOL,
                        PAD_SYMBOL, 1'b0, 1'b0);
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;

      if (!link_latched) begin
        if (rx_valid && rx_bytes.sym1_link_number != PAD_SYMBOL) begin
          configured_link_number = rx_bytes.sym1_link_number;
          link_latched            = 1'b1;
          consec_link_match_cnt   = 0;
          `uvm_info(name, $sformatf("RC Link Number 0x%0h observed - EP begins echoing",
                                     configured_link_number), UVM_HIGH)
        end
      end
      else begin
        if (rx_valid && rx_bytes.sym1_link_number == configured_link_number &&
            rx_lane_number[0] == PAD_SYMBOL) begin
          consec_link_match_cnt++;
        end
        else begin
          consec_link_match_cnt = 0;
        end

        if (consec_link_match_cnt >= CONSEC_TS_REQUIRED) begin
          `uvm_info(name, "Configuration.Linkwidth.Start complete - advancing to Linkwidth.Accept", UVM_HIGH)
          disable fork; //stop the TX forever loop before leaving this substate
          next_config_substate = CFG_LINKWIDTH_ACCEPT;
          next_state            = CONFIG_ST;
          return;
        end
      end

      if (ts_attempt_cnt >= ep_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_info(name, "Configuration.Linkwidth.Start timeout - returning to Detect", UVM_HIGH)
        disable fork;
        next_state = DETECT_ST;
        return;
      end
    end
  endtask : run_linkwidth_start

  // Task: run_linkwidth_accept
  // fork/join_none full duplex structure 
  // TX echoes configured_lane_number[] every symbol time - that
  // array is updated live by the RX loop below the instant new Lane Numbers arrive
  // from RC, including automatic lane-reversal compensation.
  task automatic run_linkwidth_accept(output config_substate_e next_config_substate,
                                       output ltssm_state_e     next_state);
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0] rx_lane_number [0:PCIE_MAX_LANES-1];
    bit rx_valid;
    int unsigned ts_attempt_cnt;
    bit use_reversal;

    `uvm_info(name, "Entering Configuration.Linkwidth.Accept", UVM_MEDIUM)

    ts_attempt_cnt = 0;
    use_reversal   = 1'b0;

    fork
      forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL, 1'b0, 1'b1);
    join_none

    forever begin
      bit valid_group;

      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;

      if (rx_valid) begin
        use_reversal = detect_lane_reversal(rx_lane_number);

        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
          configured_lane_number[l] = use_reversal
                                       ? rx_lane_number[ep_agent_cfg_h.active_lanes-1-l]
                                       : rx_lane_number[l];

        valid_group = 1'b1;
        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] == PAD_SYMBOL) valid_group = 1'b0;

        if (valid_group) begin
          `uvm_info(name, $sformatf("Valid Lane group received (reversal=%0b) - advancing to Lanenum.Wait",
                                     use_reversal), UVM_HIGH)
          disable fork;
          next_config_substate = CFG_LANENUM_WAIT;
          next_state            = CONFIG_ST;
          return;
        end
      end

      if (ts_attempt_cnt >= ep_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_info(name, "Configuration.Linkwidth.Accept timeout - returning to Detect", UVM_HIGH)
        disable fork;
        next_state = DETECT_ST;
        return;
      end
    end
  endtask : run_linkwidth_accept

  // Function: detect_lane_reversal
  // Returns 1 if the observed Lane Numbers run in descending order across the
  function automatic bit detect_lane_reversal(input bit [7:0] rc_lane [0:PCIE_MAX_LANES-1]);
    for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
      if (rc_lane[l] !== (ep_agent_cfg_h.active_lanes - 1 - l))
        return 1'b0;
    return 1'b1;
  endfunction : detect_lane_reversal

  //-------------------------------------------------------
  // ADDED - Task: run_polling_active
  // Spec 4.2.7.2.1. Ported from RC's Polling.Active, but rewritten in EP's own
  // fork/join_none + output-argument convention (matching run_linkwidth_start/
  // accept above) instead of RC's persistent-variable style, and made genuinely
  // functional: ts1_tx_count/consec_rx_match_cnt are both driven by real receive_ts
  // decode rather than referencing counters that are never incremented.
  //-------------------------------------------------------
  task automatic run_polling_active(output polling_substate_e next_polling_substate,
                                     output ltssm_state_e      next_state);
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_rx_match_cnt;
    time                    start_time;

    `uvm_info(name, "Entering Polling.Active", UVM_MEDIUM)

    ts1_tx_count        = 0;
    consec_rx_match_cnt = 0;
    start_time          = $time;

    fork
      forever begin
        drive_ts(OS_TS1, PAD_SYMBOL, PAD_SYMBOL, 1'b0, 1'b0);
        ts1_tx_count++;
      end
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);

      if (rx_valid && rx_bytes.sym6_15_identifier[0] == TS1_ID_BYTE &&
          rx_bytes.sym1_link_number == PAD_SYMBOL &&
          rx_lane_number[0] == PAD_SYMBOL) begin
        consec_rx_match_cnt++;
      end
      else begin
        consec_rx_match_cnt = 0;
      end

      if (ts1_tx_count >= TS1_1024_COUNT && consec_rx_match_cnt >= CONSEC_TS_COUNT) begin
        `uvm_info(name, "Polling.Active complete - advancing to Polling.Configuration", UVM_HIGH)
        disable fork;
        next_polling_substate = POLLING_CONFIG;
        next_state             = POLLING_ST;
        return;
      end

      if (($time - start_time) >= (POLLING_TIMEOUT_MS * 1ms)) begin
        `uvm_info(name, "Polling.Active timeout - returning to Detect", UVM_HIGH)
        disable fork;
        next_state = DETECT_ST;
        return;
      end
    end
  endtask : run_polling_active

  //-------------------------------------------------------
  // ADDED - Task: run_polling_configuration
  // Spec 4.2.7.2.3. Same conventions as run_polling_active above.
  //-------------------------------------------------------
  task automatic run_polling_configuration(output polling_substate_e next_polling_substate,
                                            output ltssm_state_e      next_state);
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    bit                     first_ts2_received;
    int unsigned            consec_rx_match_cnt;
    time                    start_time;

    `uvm_info(name, "Entering Polling.Configuration", UVM_MEDIUM)

    ts2_tx_count_complete = 0;
    first_ts2_received     = 1'b0;
    consec_rx_match_cnt    = 0;
    start_time             = $time;

    fork
      forever begin
        drive_ts(OS_TS2, PAD_SYMBOL, PAD_SYMBOL, 1'b0, 1'b0);
        if (first_ts2_received) ts2_tx_count_complete++;
      end
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);

      if (rx_valid && rx_bytes.sym6_15_identifier[0] == TS2_ID_BYTE &&
          rx_bytes.sym1_link_number == PAD_SYMBOL &&
          rx_lane_number[0] == PAD_SYMBOL) begin
        if (!first_ts2_received) first_ts2_received = 1'b1;
        consec_rx_match_cnt++;
      end
      else begin
        consec_rx_match_cnt = 0;
      end

      if (ts2_tx_count_complete >= MIN_TS2_TX_COMPLETE &&
          consec_rx_match_cnt   >= CONSEC_TS2_COMPLETE) begin
        `uvm_info(name, "Polling.Configuration complete - advancing to Configuration", UVM_HIGH)
        disable fork;
        next_state = CONFIG_ST;
        return;
      end

      if (($time - start_time) >= (2 * POLLING_TIMEOUT_MS * 1ms)) begin
        `uvm_info(name, "Polling.Configuration timeout - returning to Detect", UVM_HIGH)
        disable fork;
        next_state = DETECT_ST;
        return;
      end
    end
  endtask : run_polling_configuration

endinterface : pcie_phy_ep_driver_bfm

`endif
