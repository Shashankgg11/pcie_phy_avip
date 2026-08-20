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
  data_transfer_mode_e transfer_mode;
  bit        directed_speed_change;
  pcie_gen_e current_rate;
  bit        changed_speed_recovery;
  bit        successful_speed_negotiation;
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
  // Variable: symbol_lock_acquired
  // Real symbol/bit-boundary alignment - mirrors pcie_phy_rc_driver_bfm's identical fix.
  //-------------------------------------------------------
  bit symbol_lock_acquired;

  //-------------------------------------------------------
  // Variable: consec_invalid_rx_count
  // Self-healing watchdog - mirrors pcie_phy_rc_driver_bfm's identical mechanism. See that
  // file's version for the full design rationale.
  //-------------------------------------------------------
  int unsigned consec_invalid_rx_count;
  localparam int unsigned MAX_CONSEC_INVALID_RX = 3;

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
    symbol_lock_acquired     = 1'b0;
    consec_invalid_rx_count  = 0;
    ep_ready_polling_config   = 1'b0;
    ep_ready_linkwidth_start  = 1'b0;
    ep_ready_linkwidth_accept = 1'b0;
    ep_ready_lanenum_wait     = 1'b0;
    ep_ready_lanenum_accept   = 1'b0;
    ep_ready_complete         = 1'b0;
    ep_ready_idle             = 1'b0;
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
                                 input bit         autonomous_change,
                                 input bit [1:0]   elbc,
                                 input bit         no_scrambling,
                                 input bit         loopback,
                                 input bit         disable_link,
                                 input bit         hot_reset,
                                 output ts_ordered_set_bytes_t bytes);
    sym4_data_rate_t     sym4;
    sym5_training_ctrl_t sym5;
    bit [7:0]            id_byte;

    sym4.speed_change        = speed_change_req;
    sym4.autonomous_change   = autonomous_change;
    sym4.speed_32gts         = (ep_agent_cfg_h.target_link_speed >= GEN5);
    sym4.speed_16gts         = (ep_agent_cfg_h.target_link_speed >= GEN4);
    sym4.speed_8gts          = (ep_agent_cfg_h.target_link_speed >= GEN3);
    sym4.speed_5gts          = (ep_agent_cfg_h.target_link_speed >= GEN2);
    sym4.speed_2p5gts        = 1'b1;
    sym4.flit_mode_supported = ep_agent_cfg_h.flit_mode_capable;

    sym5.reserved_7    = 1'b0;
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
                           input bit speed_change_req,
                           input bit autonomous_change,
                           input bit [1:0] elbc,
                           input bit no_scrambling,
                           input bit loopback,
                           input bit disable_link,
                           input bit hot_reset,
                           input bit lane_no_per_lane);
    ts_ordered_set_bytes_t bytes;
    bit [7:0] sym_array   [0:TS_OS_LENGTH-1];
    bit       is_k_array  [0:TS_OS_LENGTH-1];
    bit [9:0] encoded     [0:PCIE_MAX_LANES-1];

    build_ts_bytes(ts_id, link_no, lane_no, speed_change_req, autonomous_change, elbc,
                    no_scrambling, loopback, disable_link, hot_reset, bytes);

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
  //-------------------------------------------------------
  // Task: acquire_symbol_lock
  // Real comma/symbol-boundary detection - mirrors pcie_phy_rc_driver_bfm's identical task.
  // See that file's version for the full design rationale (bit-ordering derivation, why
  // lane 0 alone is sufficient, why disparity is derived per-lane from which COM variant
  // each lane's window shows).
  //-------------------------------------------------------
  task automatic acquire_symbol_lock(output bit [9:0] locked_code [0:PCIE_MAX_LANES-1],
                                      output bit       found);
    bit [9:0]    window [0:PCIE_MAX_LANES-1];
    int unsigned edges_searched;

    //Bounded search - mirrors pcie_phy_rc_driver_bfm's identical fix. See that file's
    //version for the full design rationale.
    localparam int unsigned MAX_LOCK_SEARCH_EDGES = 2000;

    foreach (window[l]) window[l] = '0;
    found          = 1'b0;
    edges_searched = 0;

    while (edges_searched < MAX_LOCK_SEARCH_EDGES) begin
      @(epCb);
      edges_searched++;
      for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
        window[l] = {epCb.RX_P[l], window[l][9:1]};

      if (window[0] inside {K_COM_P, K_COM_N}) begin
        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++) begin
          locked_code[l] = window[l];
          if (window[l] == K_COM_N)      rx_lane_disparity[l] = RD_MINUS;
          else if (window[l] == K_COM_P) rx_lane_disparity[l] = RD_PLUS;
        end
        symbol_lock_acquired = 1'b1;
        found = 1'b1;
        `uvm_info(name, "Symbol lock acquired (real COM found on lane 0)", UVM_MEDIUM)
        return;
      end
    end

    `uvm_warning(name, $sformatf("acquire_symbol_lock: no COM found within %0d edges - giving up this attempt",
                                  MAX_LOCK_SEARCH_EDGES))
  endtask : acquire_symbol_lock

  //-------------------------------------------------------
  // Task: wait_for_partner_ready
  // Mirrors pcie_phy_rc_driver_bfm's identical task, using epCb. See that file's version
  // for the full cross-side-transition barrier rationale.
  //-------------------------------------------------------
  task automatic wait_for_partner_ready(ref bit partner_flag, input int unsigned max_wait_edges,
                                         output bit success);
    int unsigned edges_waited;
    edges_waited = 0;
    success = 1'b0;
    while (edges_waited < max_wait_edges) begin
      if (partner_flag) begin
        success = 1'b1;
        return;
      end
      @(epCb);
      edges_waited++;
    end
  endtask : wait_for_partner_ready

  task automatic receive_ts(output ts_ordered_set_bytes_t bytes,
                             output bit [7:0]              rx_lane_number [0:PCIE_MAX_LANES-1],
                             output bit                    valid);
    bit [7:0] sym_array  [0:TS_OS_LENGTH-1];
    bit       is_k_array [0:TS_OS_LENGTH-1];
    int       start_symbol;

    valid = 1'b1;
    start_symbol = 0;

    if (!symbol_lock_acquired) begin
      bit [9:0] locked_code [0:PCIE_MAX_LANES-1];
      bit       lock_found;
      acquire_symbol_lock(locked_code, lock_found);

      if (!lock_found) begin
        valid = 1'b0;
        foreach (rx_lane_number[l]) rx_lane_number[l] = PAD_SYMBOL;
        bytes = '0;
        return;
      end

      for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++) begin
        bit [7:0] decoded_byte;
        bit       decoded_is_k;
        bit       decoded_valid;

        decode_8b10b_symbol(locked_code[l], rx_lane_disparity[l],
                             decoded_byte, decoded_is_k, decoded_valid);
        rx_lane_disparity[l] = next_running_disparity(locked_code[l], rx_lane_disparity[l]);
        if (!decoded_valid) valid = 1'b0;

        if (l == 0) begin
          sym_array[0]  = decoded_byte;
          is_k_array[0] = decoded_is_k;
        end
      end
      start_symbol = 1;
    end

    for (int s = start_symbol; s < TS_OS_LENGTH; s++) begin
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

    //Self-healing: mirrors pcie_phy_rc_driver_bfm's identical mechanism.
    if (!valid) begin
      consec_invalid_rx_count++;
      if (consec_invalid_rx_count >= MAX_CONSEC_INVALID_RX) begin
        `uvm_warning(name, $sformatf("%0d consecutive invalid receptions - forcing symbol re-lock",
                                      consec_invalid_rx_count))
        symbol_lock_acquired   = 1'b0;
        consec_invalid_rx_count = 0;
      end
    end
    else begin
      consec_invalid_rx_count = 0;
    end
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

    //Same fix as RC and as Polling.Configuration - force a fresh comma-search rather than
    //trusting a phase that may have broken at the prior task's mid-symbol disable fork.
    symbol_lock_acquired = 1'b0;

    fork
      forever drive_ts(OS_TS1, link_latched ? configured_link_number : PAD_SYMBOL,
                        PAD_SYMBOL, 1'b0, ep_agent_cfg_h.default_autonomous_change, ep_agent_cfg_h.default_elbc, ep_agent_cfg_h.default_no_scrambling, ep_agent_cfg_h.default_loopback, ep_agent_cfg_h.default_disable_link, ep_agent_cfg_h.default_hot_reset, 1'b0);
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;

      if (ts_attempt_cnt == 1 || (ts_attempt_cnt % 32) == 0) begin
        `uvm_info(name, $sformatf("RX (Linkwidth.Start) #%0d: valid=%0d link=0x%0h lane=0x%0h id=0x%0h link_latched=%0d",
                                   ts_attempt_cnt, rx_valid, rx_bytes.sym1_link_number,
                                   rx_lane_number[0], rx_bytes.sym6_15_identifier[0], link_latched), UVM_LOW)
      end

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
          bit barrier_ok;
          `uvm_info(name, "Configuration.Linkwidth.Start local condition met - waiting for RC", UVM_HIGH)
          ep_ready_linkwidth_start = 1'b1;
          wait_for_partner_ready(rc_ready_linkwidth_start, ep_agent_cfg_h.config_timeout_ts_count * TS_OS_LENGTH * 10, barrier_ok);
          //NOT cleared here anymore - see race condition note where these flags are declared.

          if (!barrier_ok) begin
            `uvm_error(name, "Configuration.Linkwidth.Start: RC never reached readiness - returning to Detect")
            disable fork;
            next_state = DETECT_ST;
            return;
          end

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
      forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL, 1'b0, ep_agent_cfg_h.default_autonomous_change, ep_agent_cfg_h.default_elbc, ep_agent_cfg_h.default_no_scrambling, ep_agent_cfg_h.default_loopback, ep_agent_cfg_h.default_disable_link, ep_agent_cfg_h.default_hot_reset, 1'b1);
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
          bit barrier_ok;
          `uvm_info(name, "Configuration.Linkwidth.Accept local condition met - waiting for RC", UVM_HIGH)
          ep_ready_linkwidth_accept = 1'b1;
          wait_for_partner_ready(rc_ready_linkwidth_accept, ep_agent_cfg_h.config_timeout_ts_count * TS_OS_LENGTH * 10, barrier_ok);
          //NOT cleared here anymore - see race condition note where these flags are declared.

          if (!barrier_ok) begin
            `uvm_error(name, "Configuration.Linkwidth.Accept: RC never reached readiness - returning to Detect")
            disable fork;
            next_state = DETECT_ST;
            return;
          end

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
    int unsigned            rx_count_i;
    time                    start_time;

    `uvm_info(name, "Entering Polling.Active", UVM_MEDIUM)

    ts1_tx_count        = 0;
    consec_rx_match_cnt = 0;
    rx_count_i          = 0;
    start_time          = $time;

    fork
      forever begin
        drive_ts(OS_TS1, PAD_SYMBOL, PAD_SYMBOL, 1'b0, ep_agent_cfg_h.default_autonomous_change, ep_agent_cfg_h.default_elbc, ep_agent_cfg_h.default_no_scrambling, ep_agent_cfg_h.default_loopback, ep_agent_cfg_h.default_disable_link, ep_agent_cfg_h.default_hot_reset, 1'b0);
        ts1_tx_count++;
      end
    join_none

    forever begin
      rx_count_i++;

      receive_ts(rx_bytes, rx_lane_number, rx_valid);

      //Throttled: full detail every reception would be ~1024 lines just for this one state -
      //print at UVM_LOW only on the first reception and every 128th after; raise verbosity
      //to UVM_HIGH to see every single one.
      if (rx_count_i == 1 || (rx_count_i % 128) == 0) begin
        `uvm_info(name, $sformatf("RX TS1 #%0d: valid=%0d link=0x%0h lane=0x%0h n_fts=0x%0h data_rate=0x%0h train_ctrl=0x%0h id=0x%0h",
                                   rx_count_i, rx_valid, rx_bytes.sym1_link_number, rx_lane_number[0],
                                   rx_bytes.sym3_n_fts, rx_bytes.sym4_data_rate_id,
                                   rx_bytes.sym5_training_ctrl, rx_bytes.sym6_15_identifier[0]),
                  UVM_LOW)
      end
      else begin
        `uvm_info(name, $sformatf("RX TS1 #%0d: valid=%0d link=0x%0h lane=0x%0h n_fts=0x%0h data_rate=0x%0h train_ctrl=0x%0h id=0x%0h",
                                   rx_count_i, rx_valid, rx_bytes.sym1_link_number, rx_lane_number[0],
                                   rx_bytes.sym3_n_fts, rx_bytes.sym4_data_rate_id,
                                   rx_bytes.sym5_training_ctrl, rx_bytes.sym6_15_identifier[0]),
                  UVM_HIGH)
      end

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
  // Spec 4.2.7.2.3. Same conventions as run_polling_active above. Added throttled UVM_LOW
  // RX-content visibility matching run_polling_active - was previously invisible whether
  // zero or some-but-insufficient TS2s were being received.
  //-------------------------------------------------------
  task automatic run_polling_configuration(output polling_substate_e next_polling_substate,
                                            output ltssm_state_e      next_state);
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    bit                     first_ts2_received;
    int unsigned            consec_rx_match_cnt;
    int unsigned            rx_attempt_i;
    time                    start_time;

    `uvm_info(name, "Entering Polling.Configuration", UVM_MEDIUM)

    ts2_tx_count_complete = 0;
    first_ts2_received     = 1'b0;
    consec_rx_match_cnt    = 0;
    rx_attempt_i            = 0;
    start_time              = $time;

    //Fix: mirrors RC's identical fix - run_polling_active()'s TX thread was killed mid-symbol
    //via disable fork, breaking the partner's already-established symbol_lock_acquired
    //phase. Confirmed by direct evidence: every RX TS2 reception showed valid=0. Forcing a
    //fresh comma-search here self-corrects it.
    symbol_lock_acquired = 1'b0;

    fork
      forever begin
        drive_ts(OS_TS2, PAD_SYMBOL, PAD_SYMBOL, 1'b0, ep_agent_cfg_h.default_autonomous_change, ep_agent_cfg_h.default_elbc, ep_agent_cfg_h.default_no_scrambling, ep_agent_cfg_h.default_loopback, ep_agent_cfg_h.default_disable_link, ep_agent_cfg_h.default_hot_reset, 1'b0);
        if (first_ts2_received) ts2_tx_count_complete++;
      end
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      rx_attempt_i++;

      if (rx_attempt_i == 1 || (rx_attempt_i % 128) == 0) begin
        `uvm_info(name, $sformatf("RX TS2 #%0d: valid=%0d link=0x%0h lane=0x%0h id=0x%0h ts2_tx_count_complete=%0d",
                                   rx_attempt_i, rx_valid, rx_bytes.sym1_link_number,
                                   rx_lane_number[0], rx_bytes.sym6_15_identifier[0],
                                   ts2_tx_count_complete), UVM_LOW)
      end

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
        bit barrier_ok;
        `uvm_info(name, "Polling.Configuration local condition met - waiting for RC", UVM_HIGH)
        ep_ready_polling_config = 1'b1;
        wait_for_partner_ready(rc_ready_polling_config, ep_agent_cfg_h.config_timeout_ts_count * TS_OS_LENGTH * 10, barrier_ok);
        //NOT cleared here anymore - see race condition note where these flags are declared.

        if (!barrier_ok) begin
          `uvm_error(name, "Polling.Configuration: RC never reached readiness - returning to Detect")
          disable fork;
          next_state = DETECT_ST;
          return;
        end

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

  //-------------------------------------------------------
  // Task: receive_idle    [NEW - mirrors RC's, needed by run_configuration_idle below]
  //-------------------------------------------------------
  task automatic receive_idle(output bit [7:0] rx_byte [0:PCIE_MAX_LANES-1],
                               output bit       rx_ok   [0:PCIE_MAX_LANES-1]);
    bit [9:0] rx_encoded [0:PCIE_MAX_LANES-1];

    for (int b = 0; b < 10; b++) begin
      @(epCb);
      for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
        rx_encoded[l][b] = epCb.RX_P[l];
    end

    for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++) begin
      bit decoded_is_k;
      decode_8b10b_symbol(rx_encoded[l], rx_lane_disparity[l], rx_byte[l], decoded_is_k, rx_ok[l]);
      rx_lane_disparity[l] = next_running_disparity(rx_encoded[l], rx_lane_disparity[l]);
    end
  endtask : receive_idle

  //---------------------------------------------------------------------------------------------------------------------------------
  //    POLLING COMPLIANCE   [NEW - mirrors RC's]
  //---------------------------------------------------------------------------------------------------------------------------------
  task automatic run_polling_compliance(output polling_substate_e next_polling_substate,
                                         output ltssm_state_e      next_state);
    `uvm_info(name, "Entering Polling.Compliance", UVM_MEDIUM)

    forever begin
      drive_ts(OS_TS1, PAD_SYMBOL, PAD_SYMBOL,
                1'b0, ep_agent_cfg_h.default_autonomous_change, ep_agent_cfg_h.default_elbc,
                ep_agent_cfg_h.default_no_scrambling, ep_agent_cfg_h.default_loopback,
                ep_agent_cfg_h.default_disable_link, ep_agent_cfg_h.default_hot_reset, 1'b0);

      if (exit_compliance_req) begin
        `uvm_info(name, "Polling.Compliance: exit requested", UVM_LOW)
        exit_compliance_req = 1'b0;
        next_state = DETECT_ST;
        return;
      end
    end
  endtask : run_polling_compliance

  //---------------------------------------------------------------------------------------------------------------------------------
  //    CONFIGURATION.LANENUM    [NEW - mirrors RC's]
  //---------------------------------------------------------------------------------------------------------------------------------
  task automatic run_configuration_lanenum_wait(output config_substate_e next_config_substate,
                                                  output ltssm_state_e     next_state);
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_match_cnt;
    int unsigned            ts_attempt_cnt;
    bit                     valid_lane_group;

    `uvm_info(name, "Entering Configuration.Lanenum.Wait", UVM_MEDIUM)

    consec_match_cnt = 0;
    ts_attempt_cnt   = 0;

    fork
      forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL,
                        1'b0, ep_agent_cfg_h.default_autonomous_change, ep_agent_cfg_h.default_elbc,
                        ep_agent_cfg_h.default_no_scrambling, ep_agent_cfg_h.default_loopback,
                        ep_agent_cfg_h.default_disable_link, ep_agent_cfg_h.default_hot_reset, 1'b1);
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;

      if (rx_valid) begin
        valid_lane_group = 1'b1;
        if (rx_bytes.sym1_link_number != configured_link_number) valid_lane_group = 1'b0;
        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != configured_lane_number[l]) valid_lane_group = 1'b0;

        consec_match_cnt = valid_lane_group ? consec_match_cnt + 1 : 0;

        if (consec_match_cnt >= CONSEC_TS_REQUIRED) begin
          bit barrier_ok;
          `uvm_info(name, "Configuration.Lanenum.Wait local condition met - waiting for RC", UVM_HIGH)
          ep_ready_lanenum_wait = 1'b1;
          wait_for_partner_ready(rc_ready_lanenum_wait, ep_agent_cfg_h.config_timeout_ts_count * TS_OS_LENGTH * 10, barrier_ok);
          //NOT cleared here anymore - see race condition note where these flags are declared.

          if (!barrier_ok) begin
            `uvm_error(name, "Configuration.Lanenum.Wait: RC never reached readiness - returning to Detect")
            disable fork;
            next_state = DETECT_ST;
            return;
          end

          `uvm_info(name, "Configuration.Lanenum.Wait completed", UVM_HIGH)
          disable fork;
          next_config_substate = CFG_LANENUM_ACCEPT;
          next_state             = CONFIG_ST;
          return;
        end
      end

      if (ts_attempt_cnt >= ep_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_error(name, "Configuration.Lanenum.Wait Timeout")
        disable fork;
        next_state = DETECT_ST;
        return;
      end
    end
  endtask : run_configuration_lanenum_wait

  task automatic run_configuration_lanenum_accept(output config_substate_e next_config_substate,
                                                    output ltssm_state_e     next_state);
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_match_cnt;
    int unsigned            ts_attempt_cnt;
    bit                     valid_group;
    bit                     smaller_link_detected;
    bit                     any_non_pad;

    `uvm_info(name, "Entering Configuration.Lanenum.Accept", UVM_MEDIUM)

    consec_match_cnt      = 0;
    ts_attempt_cnt         = 0;
    smaller_link_detected = 1'b0;

    fork
      forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL,
                        1'b0, ep_agent_cfg_h.default_autonomous_change, ep_agent_cfg_h.default_elbc,
                        ep_agent_cfg_h.default_no_scrambling, ep_agent_cfg_h.default_loopback,
                        ep_agent_cfg_h.default_disable_link, ep_agent_cfg_h.default_hot_reset, 1'b1);
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;

      if (rx_valid) begin
        valid_group = 1'b1;
        if (rx_bytes.sym1_link_number != configured_link_number) valid_group = 1'b0;
        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != configured_lane_number[l]) valid_group = 1'b0;

        smaller_link_detected = 1'b0;
        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
          if ((configured_lane_number[l] != PAD_SYMBOL) && (rx_lane_number[l] == PAD_SYMBOL))
            smaller_link_detected = 1'b1;

        consec_match_cnt = valid_group ? consec_match_cnt + 1 : 0;

        if (consec_match_cnt >= CONSEC_TS_REQUIRED) begin
          bit barrier_ok;
          `uvm_info(name, "Configuration.Lanenum.Accept local condition met - waiting for RC", UVM_HIGH)
          ep_ready_lanenum_accept = 1'b1;
          wait_for_partner_ready(rc_ready_lanenum_accept, ep_agent_cfg_h.config_timeout_ts_count * TS_OS_LENGTH * 10, barrier_ok);
          //NOT cleared here anymore - see race condition note where these flags are declared.

          if (!barrier_ok) begin
            `uvm_error(name, "Configuration.Lanenum.Accept: RC never reached readiness - returning to Detect")
            disable fork;
            next_state = DETECT_ST;
            return;
          end

          `uvm_info(name, "Lane Number negotiation accepted", UVM_HIGH)
          disable fork;
          next_config_substate = CFG_COMPLETE;
          next_state             = CONFIG_ST;
          return;
        end

        if (smaller_link_detected) begin
          `uvm_info(name, "Reducing negotiated Link Width", UVM_HIGH)
          for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
            configured_lane_number[l] = rx_lane_number[l];
          disable fork;
          next_config_substate = CFG_LANENUM_WAIT;
          next_state             = CONFIG_ST;
          return;
        end

        any_non_pad = 1'b0;
        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != PAD_SYMBOL) any_non_pad = 1'b1;

        if (!any_non_pad) begin
          `uvm_warning(name, "All received Lane Numbers are PAD")
          disable fork;
          next_state = DETECT_ST;
          return;
        end
      end

      if (ts_attempt_cnt >= ep_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_error(name, "Configuration.Lanenum.Accept Timeout")
        disable fork;
        next_state = DETECT_ST;
        return;
      end
    end
  endtask : run_configuration_lanenum_accept

  //---------------------------------------------------------------------------------------------------------------------------------
  //    CONFIGURATION.COMPLETE / IDLE    [NEW - mirrors RC's]
  //---------------------------------------------------------------------------------------------------------------------------------
  task automatic run_configuration_complete(output config_substate_e next_config_substate,
                                              output ltssm_state_e     next_state);
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_ts2_cnt;
    int unsigned            ts_attempt_cnt;
    bit                     valid_group;

    `uvm_info(name, "Entering Configuration.Complete", UVM_MEDIUM)

    consec_ts2_cnt = 0;
    ts_attempt_cnt = 0;

    fork
      forever drive_ts(OS_TS2, configured_link_number, PAD_SYMBOL,
                        1'b0, ep_agent_cfg_h.default_autonomous_change, ep_agent_cfg_h.default_elbc,
                        ep_agent_cfg_h.default_no_scrambling, ep_agent_cfg_h.default_loopback,
                        ep_agent_cfg_h.default_disable_link, ep_agent_cfg_h.default_hot_reset, 1'b1);
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;

      if (rx_valid) begin
        valid_group = 1'b1;
        if (rx_bytes.sym1_link_number != configured_link_number) valid_group = 1'b0;
        for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != configured_lane_number[l]) valid_group = 1'b0;
        if (rx_bytes.sym6_15_identifier[0] != TS2_ID_BYTE) valid_group = 1'b0;

        consec_ts2_cnt = valid_group ? consec_ts2_cnt + 1 : 0;

        if (consec_ts2_cnt >= CONSEC_TS_REQUIRED) begin
          bit barrier_ok;
          `uvm_info(name, "Configuration.Complete local condition met - waiting for RC", UVM_HIGH)
          ep_ready_complete = 1'b1;
          wait_for_partner_ready(rc_ready_complete, ep_agent_cfg_h.config_timeout_ts_count * TS_OS_LENGTH * 10, barrier_ok);
          //NOT cleared here anymore - see race condition note where these flags are declared.

          if (!barrier_ok) begin
            `uvm_error(name, "Configuration.Complete: RC never reached readiness - returning to Detect")
            disable fork;
            next_state = DETECT_ST;
            return;
          end

          `uvm_info(name, "Configuration.Complete Finished", UVM_HIGH)
          disable fork;
          next_config_substate = CFG_IDLE;
          next_state             = CONFIG_ST;
          return;
        end
      end

      if (ts_attempt_cnt >= ep_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_error(name, "Configuration.Complete Timeout")
        disable fork;
        next_state = DETECT_ST;
        return;
      end
    end
  endtask : run_configuration_complete

  task automatic run_configuration_idle(output ltssm_state_e next_state);
    bit [7:0]    rx_byte [0:PCIE_MAX_LANES-1];
    bit          rx_ok   [0:PCIE_MAX_LANES-1];
    bit          all_lanes_idle;
    int unsigned idle_attempt_cnt;
    int unsigned local_idle_tx_count;
    int unsigned local_idle_rx_count;

    `uvm_info(name, "Entering Configuration.Idle", UVM_MEDIUM)

    local_idle_rx_count = 0;
    local_idle_tx_count = 0;
    idle_attempt_cnt     = 0;

    fork
      forever begin
        drive_idle();
        local_idle_tx_count++;
      end
    join_none

    forever begin
      receive_idle(rx_byte, rx_ok);
      idle_attempt_cnt++;

      all_lanes_idle = 1'b1;
      for (int l = 0; l < ep_agent_cfg_h.active_lanes; l++)
        if (!(rx_ok[l] && (rx_byte[l] == IDLE_SYMBOL))) all_lanes_idle = 1'b0;

      local_idle_rx_count = all_lanes_idle ? local_idle_rx_count + 1 : 0;

      if ((local_idle_rx_count >= MIN_IDLE_RX) && (local_idle_tx_count >= MIN_IDLE_TX)) begin
        bit barrier_ok;
        `uvm_info(name, "Configuration.Idle local condition met - waiting for RC", UVM_HIGH)
        ep_ready_idle = 1'b1;
        wait_for_partner_ready(rc_ready_idle, ep_agent_cfg_h.config_timeout_ts_count * TS_OS_LENGTH * 10, barrier_ok);
        //NOT cleared here anymore - see race condition note where these flags are declared.

        if (!barrier_ok) begin
          `uvm_error(name, "Configuration.Idle: RC never reached readiness - returning to Detect")
          disable fork;
          next_state = DETECT_ST;
          return;
        end

        `uvm_info(name, "Configuration.Idle completed - Link Up (L0)", UVM_LOW)
        disable fork;
        next_state = L0_ST;
        return;
      end

      if (idle_attempt_cnt >= ep_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_error(name, "Configuration.Idle Timeout")
        disable fork;
        next_state = DETECT_ST;
        return;
      end
    end
  endtask : run_configuration_idle

  //-------------------------------------------------------
  // Task: sample_one_symbol
  // Lightweight RX helper for run_l0()'s error/idle tracking - lane 0 only. Mirrors
  // pcie_phy_rc_driver_bfm's identical task.
  //-------------------------------------------------------
  task automatic sample_one_symbol(output bit [7:0] byte_val, output bit is_k, output bit valid);
    bit [9:0] code;
    for (int b = 0; b < 10; b++) begin
      @(epCb);
      code[b] = epCb.RX_P[0];
    end
    decode_8b10b_symbol(code, rx_lane_disparity[0], byte_val, is_k, valid);
    rx_lane_disparity[0] = next_running_disparity(code, rx_lane_disparity[0]);
  endtask : sample_one_symbol

  //-------------------------------------------------------
  // Task: run_l0
  // Mirrors pcie_phy_rc_driver_bfm's run_l0() exactly - same 4 exit conditions, same
  // simplified scope (TX-side data helpers and the partner-initiated TS1 qualification
  // tracker are not present, matching RC's current state). Uses EP's own output-argument
  // convention instead of RC's global-variable style, matching every other EP task.
  //-------------------------------------------------------
  task automatic run_l0(output ltssm_state_e next_state, output recovery_reason_e next_recovery_reason_out);
    int unsigned consec_rx_errors;
    realtime     last_legit_rx_time;

    localparam int unsigned MAX_CONSEC_RX_ERRORS  = 8;
    localparam realtime     L0_IDLE_RX_TIMEOUT    = 10ms;

    `uvm_info(name, "Entering L0", UVM_MEDIUM)

    current_rate                  = current_speed;
    directed_speed_change         = 1'b0;
    changed_speed_recovery        = 1'b0;
    successful_speed_negotiation  = 1'b0;

    transfer_mode = (current_speed >= FLIT_MODE_MANDATORY_FROM_GEN)
                    ? FLIT_MODE : ep_agent_cfg_h.preferred_transfer_mode;

    consec_rx_errors   = 0;
    last_legit_rx_time = $realtime;

    forever begin
      bit [7:0] rx_byte;
      bit       rx_is_k;
      bit       rx_valid;

      sample_one_symbol(rx_byte, rx_is_k, rx_valid);

      if (rx_valid) begin
        consec_rx_errors   = 0;
        last_legit_rx_time = $realtime;
      end
      else begin
        consec_rx_errors++;
      end

      if (recovery_request) begin
        `uvm_info(name, "L0: directed Recovery request", UVM_LOW)
        recovery_request = 1'b0;
        next_state             = RECOVERY_ST;
        next_recovery_reason_out = RECOVERY_REASON_DIRECTED;
        return;
      end

      if (current_speed != ep_agent_cfg_h.target_link_speed) begin
        directed_speed_change = 1'b1;
        `uvm_info(name, $sformatf("L0: directed_speed_change asserted (%s -> %s) - exiting L0 instantaneously",
                                   current_speed.name(),
                                   ep_agent_cfg_h.target_link_speed.name()), UVM_LOW)
        next_state             = RECOVERY_ST;
        next_recovery_reason_out = RECOVERY_REASON_SPEED_CHANGE;
        return;
      end

      if (consec_rx_errors >= MAX_CONSEC_RX_ERRORS) begin
        `uvm_warning(name, $sformatf("L0: %0d consecutive receive errors - entering Recovery",
                                      consec_rx_errors))
        next_state             = RECOVERY_ST;
        next_recovery_reason_out = RECOVERY_REASON_ERROR_THRESHOLD;
        return;
      end

      if (($realtime - last_legit_rx_time) >= L0_IDLE_RX_TIMEOUT) begin
        `uvm_warning(name, "L0: no valid symbol received for too long - entering Recovery")
        next_state             = RECOVERY_ST;
        next_recovery_reason_out = RECOVERY_REASON_IDLE_TIMEOUT;
        return;
      end
    end
  endtask : run_l0

endinterface : pcie_phy_ep_driver_bfm

`endif
