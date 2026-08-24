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
  data_transfer_mode_e transfer_mode; //resolved once at L0 entry - see run_l0()

  // speed-change bookkeeping - RC decides when to climb, EP just follows
  bit        directed_speed_change;
  pcie_gen_e current_rate;
  bit        changed_speed_recovery;
  bit        successful_speed_negotiation;

  bit [7:0]    configured_link_number;
  bit [7:0]    configured_lane_number [0:PCIE_MAX_LANES-1];
  int unsigned ts1_tx_count;
  int unsigned ts2_tx_count_complete;
  int unsigned idle_tx_count;

  //Each active lane's OWN running disparity for its 8b/10b encoder - a per-lane property,
  running_disparity_e lane_disparity [0:PCIE_MAX_LANES-1];

  //Each active lane's OWN running disparity for its 8b/10b DECODER (RX side).
  running_disparity_e rx_lane_disparity [0:PCIE_MAX_LANES-1];

  // symbol alignment, once found, stays valid until reset() - lane 0 is enough
  // since all lanes are driven in lockstep
  bit symbol_lock_acquired;

  // counts back-to-back bad decodes - forces a re-lock if alignment quietly breaks
  int unsigned consec_invalid_rx_count;
  localparam int unsigned MAX_CONSEC_INVALID_RX = 3;

  // L0 TX queues - no sequencer hookup yet, push data via push_tlp/push_dllp/push_flit_payload
  typedef bit [7:0] byte_queue_t [$];
  typedef bit [7:0] flit_payload_t [0:FLIT_TLP_PAYLOAD_BYTES-1];

  byte_queue_t    tlp_tx_queue  [$];
  byte_queue_t    dllp_tx_queue [$];
  flit_payload_t  flit_tx_queue [$];

  // current/next LTSSM state tracking
  ltssm_state_e      current_state;
  ltssm_state_e      next_state;
  recovery_reason_e  next_recovery_reason;
  recovery_substate_e current_recovery_substate;
  recovery_substate_e next_recovery_substate;

  // set once equalization completes at the current speed - a later speed bump
  // clears this so equalization gets redone
  bit equalization_done_this_speed;

  // Tx preset RC picks for Phase 0 - kept at interface scope so the RX check
  // can compare against what we actually sent
  bit [7:0] negotiated_tx_preset;
  detect_substate_e  current_detect_substate;
  detect_substate_e  next_detect_substate;
  polling_substate_e current_polling_substate;
  polling_substate_e next_polling_substate;
  config_substate_e  current_config_substate;
  config_substate_e  next_config_substate;

  //RX-side match/count tracking, referenced by Polling/Linkwidth/Idle tasks
  int unsigned ts1_rx_count;
  int unsigned ts2_rx_count;
  int unsigned idle_rx_count;

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
    idle_rx_count            = 0;
    symbol_lock_acquired     = 1'b0;
    consec_invalid_rx_count  = 0;
    rc_ready_polling_config   = 1'b0;
    rc_ready_linkwidth_start  = 1'b0;
    rc_ready_linkwidth_accept = 1'b0;
    rc_ready_lanenum_wait     = 1'b0;
    rc_ready_lanenum_accept   = 1'b0;
    rc_ready_complete         = 1'b0;
    rc_ready_idle             = 1'b0;
    tlp_tx_queue.delete();
    equalization_done_this_speed = 1'b0;
    dllp_tx_queue.delete();
    flit_tx_queue.delete();
  endtask : default_values

  //-------------------------------------------------------
  // Function: encode_8b10b_symbol
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
        IDL_SYM:    encode_8b10b_symbol = (cur_rd == RD_MINUS) ? K_IDL_N : K_IDL_P;
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
    else if (encoded_symbol inside {K_IDL_P, K_IDL_N}) begin
      byte_val = IDL_SYM; is_k_code = 1'b1;
    end
    else begin
      bit found;
      found = 1'b0;
      for (int b = 0; b < 256; b++) begin
        if (D_POS_DISP[b] == encoded_symbol || D_NEG_DISP[b] == encoded_symbol) begin
          byte_val = b[7:0];
          found    = 1'b1;
          break;
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
    sym4.speed_32gts         = (rc_agent_cfg_h.target_link_speed >= GEN5);
    sym4.speed_16gts         = (rc_agent_cfg_h.target_link_speed >= GEN4);
    sym4.speed_8gts          = (rc_agent_cfg_h.target_link_speed >= GEN3);
    sym4.speed_5gts          = (rc_agent_cfg_h.target_link_speed >= GEN2);
    sym4.speed_2p5gts        = 1'b1;
    sym4.flit_mode_supported = rc_agent_cfg_h.flit_mode_capable;

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

    sym_array[0] = bytes.sym0_com;           is_k_array[0] = 1'b1;
    sym_array[1] = bytes.sym1_link_number;   is_k_array[1] = 1'b0;
    sym_array[3] = bytes.sym3_n_fts;         is_k_array[3] = 1'b0;
    sym_array[4] = bytes.sym4_data_rate_id;  is_k_array[4] = 1'b0;
    sym_array[5] = bytes.sym5_training_ctrl; is_k_array[5] = 1'b0;
    for (int i = 0; i < 10; i++) begin
      sym_array[6+i] = bytes.sym6_15_identifier[i];
      is_k_array[6+i] = 1'b0;
    end

    for (int s = 0; s < TS_OS_LENGTH; s++) begin
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
        bit [7:0] this_byte;
        this_byte = (s == 2) ? (lane_no_per_lane ? configured_lane_number[l] : lane_no)
                              : sym_array[s];
        encoded[l] = encode_8b10b_symbol(this_byte, is_k_array[s], lane_disparity[l]);
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
    end
  endtask : drive_ts

  //-------------------------------------------------------
  // Task: acquire_symbol_lock
  //-------------------------------------------------------
  task automatic acquire_symbol_lock(output bit [9:0] locked_code [0:PCIE_MAX_LANES-1],
                                      output bit       found);
    bit [9:0]    window [0:PCIE_MAX_LANES-1];
    int unsigned edges_searched;

    //Bounded search - was an unbounded forever loop, which could hang the simulation
    //indefinitely if the partner's content genuinely never produces a decodable COM.
    localparam int unsigned MAX_LOCK_SEARCH_EDGES = 2000;

    foreach (window[l]) window[l] = '0;
    found          = 1'b0;
    edges_searched = 0;

    while (edges_searched < MAX_LOCK_SEARCH_EDGES) begin
      @(rcCb);
      edges_searched++;
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        window[l] = {rcCb.RX_P[l], window[l][9:1]};

      if (window[0] inside {K_COM_P, K_COM_N}) begin
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
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

  // same idea as acquire_symbol_lock, but for Idle phases - Configuration.Idle
  // and Recovery.Idle never send a COM, so searching for one there can never
  // succeed. Searches for IDLE_SYMBOL's own known bit pattern instead.
  task automatic acquire_idle_symbol_lock(output bit [9:0] locked_code [0:PCIE_MAX_LANES-1],
                                           output bit       found);
    bit [9:0]    window [0:PCIE_MAX_LANES-1];
    int unsigned edges_searched;
    localparam int unsigned MAX_LOCK_SEARCH_EDGES = 2000;

    foreach (window[l]) window[l] = '0;
    found          = 1'b0;
    edges_searched = 0;

    while (edges_searched < MAX_LOCK_SEARCH_EDGES) begin
      @(rcCb);
      edges_searched++;
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        window[l] = {rcCb.RX_P[l], window[l][9:1]};

      if (window[0] == D_NEG_DISP[IDLE_SYMBOL] || window[0] == D_POS_DISP[IDLE_SYMBOL]) begin
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
          locked_code[l] = window[l];
          if (window[l] == D_NEG_DISP[IDLE_SYMBOL])      rx_lane_disparity[l] = RD_MINUS;
          else if (window[l] == D_POS_DISP[IDLE_SYMBOL]) rx_lane_disparity[l] = RD_PLUS;
        end
        symbol_lock_acquired = 1'b1;
        found = 1'b1;
        `uvm_info(name, "Symbol lock acquired (Idle pattern found on lane 0)", UVM_MEDIUM)
        return;
      end
    end

    `uvm_warning(name, $sformatf("acquire_idle_symbol_lock: no Idle pattern found within %0d edges - giving up this attempt",
                                  MAX_LOCK_SEARCH_EDGES))
  endtask : acquire_idle_symbol_lock

  // waits for the partner's ready flag without killing our own TX loop, so both
  // sides stay on matching content until they're both ready to move on
  task automatic wait_for_partner_ready(ref bit partner_flag, input time max_wait_time,
                                         output bit success);
    time start_time;
    start_time = $time;
    success = 1'b0;
    while (($time - start_time) < max_wait_time) begin
      if (partner_flag) begin
        success = 1'b1;
        return;
      end
      @(rcCb);
    end
  endtask : wait_for_partner_ready

  //-------------------------------------------------------
  // Task: receive_ts
  //-------------------------------------------------------
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

      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
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

    //Self-healing: sustained invalid decoding means the phase is genuinely broken - force a
    //fresh comma-search on the NEXT call rather than staying wrong forever.
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

  // sends Modified TS1/TS2 (Gen3+) - reuses the 8b/10b encoder as a stand-in for
  // real 128b/130b, but framing (parity + replica) is accurate. No COM/K-codes here.
  task automatic drive_modified_ts(input modified_ts_bytes_t content);
    bit [7:0] stream [];
    bit       is_k   [];
    bit [7:0] parity;

    stream = new[16];
    is_k   = new[16];

    stream[0] = content.id;           is_k[0] = 1'b0;
    stream[1] = content.link_number;  is_k[1] = 1'b0;
    stream[2] = content.lane_number;  is_k[2] = 1'b0;
    stream[3] = content.n_fts;        is_k[3] = 1'b0;
    stream[4] = content.data_rate_id; is_k[4] = 1'b0;
    stream[5] = content.ec_byte;      is_k[5] = 1'b0;
    stream[6] = content.payload;      is_k[6] = 1'b0;

    parity = stream[0] ^ stream[1] ^ stream[2] ^ stream[3] ^ stream[4] ^ stream[5] ^ stream[6];
    stream[7] = parity; is_k[7] = 1'b0;

    for (int i = 0; i < 7; i++) begin
      stream[8+i] = stream[i]; //replica of bytes 0-6
      is_k[8+i]   = 1'b0;
    end
    stream[15] = parity; is_k[15] = 1'b0;

    drive_symbol_stream(stream, is_k);
  endtask : drive_modified_ts

  // reads 16 fixed symbols, no comma search needed since we're already locked -
  // checks both parity bytes and the replica match
  task automatic receive_modified_ts(output modified_ts_bytes_t content, output bit valid);
    bit [7:0] rx_byte [0:15];
    bit       rx_ok   [0:15];
    bit [7:0] computed_parity_primary;
    bit [7:0] computed_parity_replica;
    bit       replica_match;

    valid = 1'b1;

    for (int s = 0; s < 16; s++) begin
      bit [9:0] rx_encoded;
      bit       decoded_is_k;

      for (int b = 0; b < 10; b++) begin
        @(rcCb);
        rx_encoded[b] = rcCb.RX_P[0];
      end

      decode_8b10b_symbol(rx_encoded, rx_lane_disparity[0], rx_byte[s], decoded_is_k, rx_ok[s]);
      rx_lane_disparity[0] = next_running_disparity(rx_encoded, rx_lane_disparity[0]);

      if (!rx_ok[s] || decoded_is_k) valid = 1'b0; //Modified TS bytes are never K-codes
    end

    content.id           = rx_byte[0];
    content.link_number  = rx_byte[1];
    content.lane_number  = rx_byte[2];
    content.n_fts         = rx_byte[3];
    content.data_rate_id = rx_byte[4];
    content.ec_byte       = rx_byte[5];
    content.payload       = rx_byte[6];

    computed_parity_primary = rx_byte[0] ^ rx_byte[1] ^ rx_byte[2] ^ rx_byte[3] ^
                               rx_byte[4] ^ rx_byte[5] ^ rx_byte[6];
    if (computed_parity_primary != rx_byte[7]) valid = 1'b0;

    replica_match = 1'b1;
    for (int i = 0; i < 7; i++)
      if (rx_byte[8+i] != rx_byte[i]) replica_match = 1'b0;
    if (!replica_match) valid = 1'b0;

    computed_parity_replica = rx_byte[8] ^ rx_byte[9] ^ rx_byte[10] ^ rx_byte[11] ^
                               rx_byte[12] ^ rx_byte[13] ^ rx_byte[14];
    if (computed_parity_replica != rx_byte[15]) valid = 1'b0;
  endtask : receive_modified_ts

  //-------------------------------------------------------
  // Task: drive_idle
  //-------------------------------------------------------
  task automatic drive_idle();
    bit [9:0] encoded [0:PCIE_MAX_LANES-1];

    for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
      encoded[l] = encode_8b10b_symbol(IDLE_SYMBOL, 1'b0, lane_disparity[l]);
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
  // Task: receive_idle    [NEW - needed by run_configuration_idle below]
  //-------------------------------------------------------
  task automatic receive_idle(output bit [7:0] rx_byte [0:PCIE_MAX_LANES-1],
                               output bit       rx_ok   [0:PCIE_MAX_LANES-1]);
    bit [9:0] rx_encoded [0:PCIE_MAX_LANES-1];
    bit       all_ok;

    //If the watchdog (below) forced a re-lock, search for IDLE_SYMBOL's own
    //pattern - a COM search (like receive_ts uses) can never succeed here,
    //since no COM is ever sent during this phase.
    if (!symbol_lock_acquired) begin
      bit [9:0] locked_code [0:PCIE_MAX_LANES-1];
      bit       lock_found;
      acquire_idle_symbol_lock(locked_code, lock_found);
      if (!lock_found) begin
        foreach (rx_ok[l]) rx_ok[l] = 1'b0;
        foreach (rx_byte[l]) rx_byte[l] = '0;
        return;
      end
      //locked_code IS this symbol's content - use it directly rather than re-sampling
      //(re-sampling would consume the NEXT symbol's bits instead).
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
        bit decoded_is_k;
        decode_8b10b_symbol(locked_code[l], rx_lane_disparity[l], rx_byte[l], decoded_is_k, rx_ok[l]);
        rx_lane_disparity[l] = next_running_disparity(locked_code[l], rx_lane_disparity[l]);
        if (!rx_ok[l] || decoded_is_k) rx_ok[l] = 1'b0;
      end
      consec_invalid_rx_count = 0; //fresh lock - don't immediately re-trip the watchdog
      return;
    end

    for (int b = 0; b < 10; b++) begin
      @(rcCb);
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        rx_encoded[l][b] = rcCb.RX_P[l];
    end

    all_ok = 1'b1;
    for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
      bit decoded_is_k;
      decode_8b10b_symbol(rx_encoded[l], rx_lane_disparity[l], rx_byte[l], decoded_is_k, rx_ok[l]);
      rx_lane_disparity[l] = next_running_disparity(rx_encoded[l], rx_lane_disparity[l]);
      // must be a legal decode AND actually be an Idle symbol - a legal-but-wrong
      // byte (phase off by a fraction, still lands on some other valid D-code)
      // used to pass this check forever with no warning ever firing
      if (!rx_ok[l] || decoded_is_k || rx_byte[l] != IDLE_SYMBOL) all_ok = 1'b0;
    end

    // same re-lock watchdog as receive_ts() - used to be missing here, which is
    // what stuck RC in Configuration.Idle
    if (!all_ok) begin
      consec_invalid_rx_count++;
      if (consec_invalid_rx_count >= MAX_CONSEC_INVALID_RX) begin
        `uvm_warning(name, $sformatf("%0d consecutive invalid Idle receptions - forcing symbol re-lock",
                                      consec_invalid_rx_count))
        symbol_lock_acquired    = 1'b0;
        consec_invalid_rx_count = 0;
      end
    end
    else begin
      consec_invalid_rx_count = 0;
    end
  endtask : receive_idle

  //-------------------------------------------------------
  // Function: check_electrical_idle_exit_any_lane
  //-------------------------------------------------------
  function automatic bit check_electrical_idle_exit_any_lane();
    return ELECTRICAL_IDLE_EXIT_ASSUMED;
  endfunction : check_electrical_idle_exit_any_lane

  //-------------------------------------------------------
  // Function: perform_receiver_detection_all_lanes
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
  // Function: detect_lane_reversal
  //-------------------------------------------------------
  function automatic bit detect_lane_reversal(input bit [7:0] ep_lane [0:PCIE_MAX_LANES-1]);
    for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
      if (ep_lane[l] !== (rc_agent_cfg_h.active_lanes - 1 - l))
        return 1'b0;
    return 1'b1;
  endfunction : detect_lane_reversal

  //-------------------------------------------------------
  //    DETECT
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
      next_state             = POLLING_ST;
      next_polling_substate  = POLLING_ACTIVE;
      return;
    end

    `uvm_info(name, "Partial receiver detection - retrying Receiver Detection", UVM_HIGH)
    repeat (rc_agent_cfg_h.detect_timeout_cycles) @(rcCb);

    pass2_mask = perform_receiver_detection_all_lanes();

    if (pass2_mask == expected_mask) begin
      `uvm_info(name, "Receiver detected on retry - moving to Polling", UVM_HIGH)
      next_state             = POLLING_ST;
      next_polling_substate  = POLLING_ACTIVE;
    end
    else begin
      `uvm_info(name, "Receiver detection failed - returning to Detect.Quiet", UVM_HIGH)
      next_state           = DETECT_ST;
      next_detect_substate = DETECT_QUIET;
    end
  endtask : run_detect_active

  //-------------------------------------------------------
  //    CONFIGURATION.LINKWIDTH
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
    configured_link_number  = rc_agent_cfg_h.link_number;

    fork
      forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL,
                        1'b0, rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                        rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                        rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b0);
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
        bit barrier_ok;
        `uvm_info(name, $sformatf("Configuration.Linkwidth.Start: %0d consecutive REAL matches confirmed - last RX: link=0x%0h lane=0x%0h id=0x%0h (expected link=0x%0h lane=PAD id=TS1_ID_BYTE)",
                                   consec_link_match_cnt, rx_bytes.sym1_link_number, rx_lane_number[0],
                                   rx_bytes.sym6_15_identifier[0], configured_link_number), UVM_LOW)
        `uvm_info(name, "Configuration.Linkwidth.Start local condition met - waiting for EP", UVM_HIGH)
        rc_ready_linkwidth_start = 1'b1;
        wait_for_partner_ready(ep_ready_linkwidth_start, time'(TIMEOUT_LINKWIDTH_MS * 1ms), barrier_ok);
        //NOT cleared here anymore - see race condition note where these flags are declared.

        if (!barrier_ok) begin
          `uvm_error(name, "Configuration.Linkwidth.Start: EP never reached readiness - returning to Detect")
          disable fork;
          next_state           = DETECT_ST;
          next_detect_substate = DETECT_QUIET;
          return;
        end

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
                        1'b0, rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                        rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                        rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b1);
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
          bit barrier_ok;
          `uvm_info(name, $sformatf("Configuration.Linkwidth.Accept: REAL valid Lane group RX: lane0=0x%0h lane1=0x%0h lane2=0x%0h lane3=0x%0h (none PAD=0xf7)",
                                     rx_lane_number[0], rx_lane_number[1], rx_lane_number[2], rx_lane_number[3]), UVM_LOW)
          `uvm_info(name, "Configuration.Linkwidth.Accept local condition met - waiting for EP", UVM_HIGH)
          rc_ready_linkwidth_accept = 1'b1;
          wait_for_partner_ready(ep_ready_linkwidth_accept, time'(TIMEOUT_LINKWIDTH_MS * 1ms), barrier_ok);
          //NOT cleared here anymore - see race condition note where these flags are declared.

          if (!barrier_ok) begin
            `uvm_error(name, "Configuration.Linkwidth.Accept: EP never reached readiness - returning to Detect")
            disable fork;
            next_state           = DETECT_ST;
            next_detect_substate = DETECT_QUIET;
            return;
          end

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

  //-------------------------------------------------------
  //    CONFIGURATION.LANENUM    [NEW]
  //-------------------------------------------------------
  task automatic run_configuration_lanenum_wait();
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_match_cnt;
    int unsigned            ts_attempt_cnt;
    bit                     valid_lane_group;

    `uvm_info(name, "Entering Configuration.Lanenum.Wait", UVM_MEDIUM)

    current_state           = CONFIG_ST;
    current_config_substate = CFG_LANENUM_WAIT;

    consec_match_cnt = 0;
    ts_attempt_cnt   = 0;

    fork
      forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL,
                        1'b0, rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                        rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                        rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b1);
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;
      ts1_rx_count++;

      if (rx_valid) begin
        valid_lane_group = 1'b1;
        if (rx_bytes.sym1_link_number != configured_link_number) valid_lane_group = 1'b0;
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != configured_lane_number[l]) valid_lane_group = 1'b0;

        consec_match_cnt = valid_lane_group ? consec_match_cnt + 1 : 0;

        if (consec_match_cnt >= CONSEC_TS_REQUIRED) begin
          bit barrier_ok;
          `uvm_info(name, $sformatf("Configuration.Lanenum.Wait: %0d consecutive REAL matches - RX link=0x%0h lane0=0x%0h (expected link=0x%0h lane0=0x%0h)",
                                     consec_match_cnt, rx_bytes.sym1_link_number, rx_lane_number[0],
                                     configured_link_number, configured_lane_number[0]), UVM_LOW)
          `uvm_info(name, "Configuration.Lanenum.Wait local condition met - waiting for EP", UVM_HIGH)
          rc_ready_lanenum_wait = 1'b1;
          wait_for_partner_ready(ep_ready_lanenum_wait, time'(TIMEOUT_LANENUM_MS * 1ms), barrier_ok);
          //NOT cleared here anymore - see race condition note where these flags are declared.

          if (!barrier_ok) begin
            `uvm_error(name, "Configuration.Lanenum.Wait: EP never reached readiness - returning to Detect")
            disable fork;
            next_state           = DETECT_ST;
            next_detect_substate = DETECT_QUIET;
            return;
          end

          `uvm_info(name, "Configuration.Lanenum.Wait completed", UVM_HIGH)
          disable fork;
          next_state            = CONFIG_ST;
          next_config_substate  = CFG_LANENUM_ACCEPT;
          return;
        end
      end

      if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_error(name, "Configuration.Lanenum.Wait Timeout")
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_configuration_lanenum_wait

  task automatic run_configuration_lanenum_accept();
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_match_cnt;
    int unsigned            ts_attempt_cnt;
    bit                     valid_group;
    bit                     smaller_link_detected;
    bit                     any_non_pad;

    `uvm_info(name, "Entering Configuration.Lanenum.Accept", UVM_MEDIUM)

    current_state           = CONFIG_ST;
    current_config_substate = CFG_LANENUM_ACCEPT;

    consec_match_cnt      = 0;
    ts_attempt_cnt         = 0;
    smaller_link_detected = 1'b0;

    fork
      forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL,
                        1'b0, rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                        rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                        rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b1);
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;
      ts1_rx_count++;

      if (rx_valid) begin
        valid_group = 1'b1;
        if (rx_bytes.sym1_link_number != configured_link_number) valid_group = 1'b0;
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != configured_lane_number[l]) valid_group = 1'b0;

        smaller_link_detected = 1'b0;
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          if ((configured_lane_number[l] != PAD_SYMBOL) && (rx_lane_number[l] == PAD_SYMBOL))
            smaller_link_detected = 1'b1;

        consec_match_cnt = valid_group ? consec_match_cnt + 1 : 0;

        if (consec_match_cnt >= CONSEC_TS_REQUIRED) begin
          bit barrier_ok;
          `uvm_info(name, $sformatf("Configuration.Lanenum.Accept: %0d consecutive REAL matches - RX link=0x%0h lane0=0x%0h (expected link=0x%0h lane0=0x%0h)",
                                     consec_match_cnt, rx_bytes.sym1_link_number, rx_lane_number[0],
                                     configured_link_number, configured_lane_number[0]), UVM_LOW)
          `uvm_info(name, "Configuration.Lanenum.Accept local condition met - waiting for EP", UVM_HIGH)
          rc_ready_lanenum_accept = 1'b1;
          wait_for_partner_ready(ep_ready_lanenum_accept, time'(TIMEOUT_LANENUM_MS * 1ms), barrier_ok);
          //NOT cleared here anymore - see race condition note where these flags are declared.

          if (!barrier_ok) begin
            `uvm_error(name, "Configuration.Lanenum.Accept: EP never reached readiness - returning to Detect")
            disable fork;
            next_state           = DETECT_ST;
            next_detect_substate = DETECT_QUIET;
            return;
          end

          `uvm_info(name, "Lane Number negotiation accepted", UVM_HIGH)
          disable fork;
          next_state            = CONFIG_ST;
          next_config_substate  = CFG_COMPLETE;
          return;
        end

        if (smaller_link_detected) begin
          `uvm_info(name, "Reducing negotiated Link Width", UVM_HIGH)
          for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
            configured_lane_number[l] = rx_lane_number[l];
          disable fork;
          next_state            = CONFIG_ST;
          next_config_substate  = CFG_LANENUM_WAIT;
          return;
        end

        any_non_pad = 1'b0;
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != PAD_SYMBOL) any_non_pad = 1'b1;

        if (!any_non_pad) begin
          `uvm_warning(name, "All received Lane Numbers are PAD")
          disable fork;
          next_state           = DETECT_ST;
          next_detect_substate = DETECT_QUIET;
          return;
        end
      end

      if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_error(name, "Configuration.Lanenum.Accept Timeout")
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_configuration_lanenum_accept

  //-------------------------------------------------------
  //    CONFIGURATION.COMPLETE / IDLE    [NEW]
  //-------------------------------------------------------
  task automatic run_configuration_complete();
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_ts2_cnt;
    int unsigned            ts_attempt_cnt;
    bit                     valid_group;

    `uvm_info(name, "Entering Configuration.Complete", UVM_MEDIUM)

    current_state           = CONFIG_ST;
    current_config_substate = CFG_COMPLETE;

    consec_ts2_cnt = 0;
    ts_attempt_cnt = 0;

    fork
      forever drive_ts(OS_TS2, configured_link_number, PAD_SYMBOL,
                        1'b0, rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                        rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                        rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b1);
    join_none

    forever begin
      receive_ts(rx_bytes, rx_lane_number, rx_valid);
      ts_attempt_cnt++;
      ts2_rx_count++;

      if (rx_valid) begin
        valid_group = 1'b1;
        if (rx_bytes.sym1_link_number != configured_link_number) valid_group = 1'b0;
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != configured_lane_number[l]) valid_group = 1'b0;
        if (rx_bytes.sym6_15_identifier[0] != TS2_ID_BYTE) valid_group = 1'b0;

        consec_ts2_cnt = valid_group ? consec_ts2_cnt + 1 : 0;

        if (consec_ts2_cnt >= CONSEC_TS_REQUIRED) begin
          bit barrier_ok;
          `uvm_info(name, $sformatf("Configuration.Complete: %0d consecutive REAL TS2 matches - RX link=0x%0h lane0=0x%0h id=0x%0h (expected id=TS2_ID_BYTE=0x45)",
                                     consec_ts2_cnt, rx_bytes.sym1_link_number, rx_lane_number[0],
                                     rx_bytes.sym6_15_identifier[0]), UVM_LOW)
          `uvm_info(name, "Configuration.Complete local condition met - waiting for EP", UVM_HIGH)
          rc_ready_complete = 1'b1;
          wait_for_partner_ready(ep_ready_complete, time'(TIMEOUT_COMPLETE_MS * 1ms), barrier_ok);
          //NOT cleared here anymore - see race condition note where these flags are declared.

          if (!barrier_ok) begin
            `uvm_error(name, "Configuration.Complete: EP never reached readiness - returning to Detect")
            disable fork;
            next_state           = DETECT_ST;
            next_detect_substate = DETECT_QUIET;
            return;
          end

          `uvm_info(name, "Configuration.Complete Finished", UVM_HIGH)
          disable fork;
          next_state            = CONFIG_ST;
          next_config_substate  = CFG_IDLE;
          return;
        end
      end

      if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_error(name, "Configuration.Complete Timeout")
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_configuration_complete

  task automatic run_configuration_idle();
    bit [7:0]    rx_byte [0:PCIE_MAX_LANES-1];
    bit          rx_ok   [0:PCIE_MAX_LANES-1];
    bit          all_lanes_idle;
    int unsigned idle_attempt_cnt;
    time         start_time;

    `uvm_info(name, "Entering Configuration.Idle", UVM_MEDIUM)

    current_state           = CONFIG_ST;
    current_config_substate = CFG_IDLE;

    idle_rx_count     = 0;
    idle_tx_count     = 0;
    idle_attempt_cnt  = 0;
    start_time        = $time;

    fork
      forever begin
        drive_idle();
        idle_tx_count++;
      end
    join_none

    forever begin
      receive_idle(rx_byte, rx_ok);
      idle_attempt_cnt++;

      all_lanes_idle = 1'b1;
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        if (!(rx_ok[l] && (rx_byte[l] == IDLE_SYMBOL))) all_lanes_idle = 1'b0;

      idle_rx_count = all_lanes_idle ? idle_rx_count + 1 : 0;

      if ((idle_rx_count >= MIN_IDLE_RX) && (idle_tx_count >= MIN_IDLE_TX)) begin
        bit barrier_ok;
        `uvm_info(name, $sformatf("Configuration.Idle: %0d consecutive REAL Idle symbols confirmed (tx=%0d)",
                                   idle_rx_count, idle_tx_count), UVM_LOW)
        `uvm_info(name, "Configuration.Idle local condition met - waiting for EP", UVM_HIGH)
        rc_ready_idle = 1'b1;
        wait_for_partner_ready(ep_ready_idle, time'(TIMEOUT_IDLE_MS * 1ms), barrier_ok);
        //NOT cleared here anymore - see race condition note where these flags are declared.

        if (!barrier_ok) begin
          `uvm_error(name, "Configuration.Idle: EP never reached readiness - returning to Detect")
          disable fork;
          next_state            = DETECT_ST;
          next_detect_substate  = DETECT_QUIET;
          idle_tx_count = 0;
          idle_rx_count = 0;
          return;
        end

        `uvm_info(name, "Configuration.Idle completed - Link Up (L0)", UVM_LOW)
        disable fork;
        next_state    = L0_ST;
        idle_tx_count = 0;
        idle_rx_count = 0;
        return;
      end

      if (($time - start_time) >= (TIMEOUT_IDLE_MS * 1ms)) begin
        `uvm_error(name, "Configuration.Idle Timeout")
        disable fork;
        next_state            = DETECT_ST;
        next_detect_substate  = DETECT_QUIET;
        idle_tx_count = 0;
        idle_rx_count = 0;
        return;
      end
    end
  endtask : run_configuration_idle

  //-------------------------------------------------------
  //    POLLING ACTIVE   [FIXED - real RX loop added, timeout units fixed]
  //-------------------------------------------------------
  task automatic run_polling_active();
    int unsigned            consec_rx_match_cnt;
    time                    start_time;

    `uvm_info(name, "Entering Polling.Active", UVM_MEDIUM)

    current_state             = POLLING_ST;
    current_polling_substate  = POLLING_ACTIVE;

    ts1_tx_count         = 0;
    consec_rx_match_cnt  = 0;
    start_time           = $time;

    fork
      forever begin
        drive_ts(OS_TS1, PAD_SYMBOL, PAD_SYMBOL,
                  1'b1, rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                  rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                  rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b0);
        ts1_tx_count++;
        `uvm_info(name, $sformatf("TX TS1 #%0d: link=0x%0h lane=0x%0h",
                                   ts1_tx_count, PAD_SYMBOL, PAD_SYMBOL), UVM_HIGH)
      end
    join_none

    forever begin
      ts_ordered_set_bytes_t rx_bytes_i;
      bit [7:0]               rx_lane_number_i [0:PCIE_MAX_LANES-1];
      bit                     rx_valid_i;

      receive_ts(rx_bytes_i, rx_lane_number_i, rx_valid_i);
      ts1_rx_count++;

      if (ts1_rx_count == 1 || (ts1_rx_count % 128) == 0) begin
        `uvm_info(name, $sformatf("RX TS1 #%0d: valid=%0d link=0x%0h lane=0x%0h n_fts=0x%0h data_rate=0x%0h train_ctrl=0x%0h id=0x%0h",
                                   ts1_rx_count, rx_valid_i, rx_bytes_i.sym1_link_number, rx_lane_number_i[0],
                                   rx_bytes_i.sym3_n_fts, rx_bytes_i.sym4_data_rate_id,
                                   rx_bytes_i.sym5_training_ctrl, rx_bytes_i.sym6_15_identifier[0]),
                  UVM_LOW)
      end
      else begin
        `uvm_info(name, $sformatf("RX TS1 #%0d: valid=%0d link=0x%0h lane=0x%0h n_fts=0x%0h data_rate=0x%0h train_ctrl=0x%0h id=0x%0h",
                                   ts1_rx_count, rx_valid_i, rx_bytes_i.sym1_link_number, rx_lane_number_i[0],
                                   rx_bytes_i.sym3_n_fts, rx_bytes_i.sym4_data_rate_id,
                                   rx_bytes_i.sym5_training_ctrl, rx_bytes_i.sym6_15_identifier[0]),
                  UVM_HIGH)
      end

      if (rx_valid_i && rx_bytes_i.sym6_15_identifier[0] == TS1_ID_BYTE) begin
        consec_rx_match_cnt++;
        `uvm_info(name, $sformatf("Received matching TS1 (%0d/%0d)",
                                   consec_rx_match_cnt, CONSEC_TS_COUNT), UVM_HIGH)
      end
      else begin
        consec_rx_match_cnt = 0;
      end

      //Success: enough TS1 sent AND enough matching TS1 received back
      if ((ts1_tx_count >= TS1_1024_COUNT) && (consec_rx_match_cnt >= CONSEC_TS_COUNT)) begin
        `uvm_info(name, "Polling.Active completed successfully", UVM_LOW)
        disable fork;
        next_state             = POLLING_ST;
        next_polling_substate  = POLLING_CONFIG;
        ts1_tx_count = 0;
        ts1_rx_count = 0;
        return;
      end

      //1024 TS1 sent with no valid response -> Polling.Compliance (spec-defined trigger,
      //a count condition, not a time-elapsed one)
      if (ts1_tx_count >= TS1_1024_COUNT) begin
        `uvm_info(name, "Polling.Active: 1024 TS1 sent with no valid response -> Polling.Compliance", UVM_LOW)
        disable fork;
        next_state             = POLLING_ST;
        next_polling_substate  = POLLING_COMPLIANCE;
        ts1_tx_count = 0;
        ts1_rx_count = 0;
        return;
      end

      //Generic safety-net timeout
      if (($time - start_time) >= (POLLING_TIMEOUT_MS * 1ms)) begin
        `uvm_error(name, "Polling.Active Timeout")
        disable fork;
        next_state            = DETECT_ST;
        next_detect_substate  = DETECT_QUIET;
        ts1_tx_count = 0;
        ts1_rx_count = 0;
        return;
      end
    end
  endtask : run_polling_active

  // ---- Polling.Compliance ----
  // no built-in exit condition - stays here until exit_compliance_req is set externally
  task automatic run_polling_compliance();
    int unsigned compliance_pattern_count;

    `uvm_info(name, "Entering Polling.Compliance", UVM_MEDIUM)

    current_state             = POLLING_ST;
    current_polling_substate  = POLLING_COMPLIANCE;
    compliance_pattern_count  = 0;

    forever begin
      // placeholder - real Compliance Pattern is a scrambled bit sequence, not
      // a TS; using TS1 shape here just for timing until this gets built out
      drive_ts(OS_TS1, PAD_SYMBOL, PAD_SYMBOL,
                1'b0, rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b0);
      compliance_pattern_count++;

      if (exit_compliance_req) begin
        `uvm_info(name, "Polling.Compliance: exit requested", UVM_LOW)
        exit_compliance_req = 1'b0;
        next_state             = DETECT_ST;
        next_detect_substate   = DETECT_QUIET;
        return;
      end
    end
  endtask : run_polling_compliance

  //-------------------------------------------------------
  //    POLLING CONFIGURE   [FIXED - real RX loop added, timeout units fixed]
  //-------------------------------------------------------
  task automatic run_polling_configuration();
    time start_time;
    bit  first_ts2_received;
    bit  lane_match;
    int unsigned rx_attempt_i;

    `uvm_info(name, "Entering Polling.Configuration", UVM_MEDIUM)

    current_state             = POLLING_ST;
    current_polling_substate  = POLLING_CONFIG;

    ts2_tx_count_complete = 0;
    ts2_rx_count          = 0;
    first_ts2_received     = 1'b0;
    rx_attempt_i           = 0;
    start_time             = $time;

    fork
      forever begin
        drive_ts(OS_TS2, PAD_SYMBOL, PAD_SYMBOL,
                  1'b1, rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                  rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                  rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b1);
        if (first_ts2_received) ts2_tx_count_complete++;
      end
    join_none

    forever begin
      ts_ordered_set_bytes_t rx_bytes_i;
      bit [7:0]               rx_lane_number_i [0:PCIE_MAX_LANES-1];
      bit                     rx_valid_i;

      receive_ts(rx_bytes_i, rx_lane_number_i, rx_valid_i);
      rx_attempt_i++;

      if (rx_attempt_i == 1 || (rx_attempt_i % 128) == 0) begin
        `uvm_info(name, $sformatf("RX TS2 #%0d: valid=%0d link=0x%0h lane=0x%0h id=0x%0h ts2_tx_count_complete=%0d",
                                   rx_attempt_i, rx_valid_i, rx_bytes_i.sym1_link_number,
                                   rx_lane_number_i[0], rx_bytes_i.sym6_15_identifier[0],
                                   ts2_tx_count_complete), UVM_LOW)
      end

      //Fixed: genuinely consecutive matching (resets to 0 on a miss) instead of a pure
      //cumulative-ever-received count, and now also checks Link/Lane match.
      lane_match = (rx_lane_number_i[0] == PAD_SYMBOL);

      if (rx_valid_i && rx_bytes_i.sym6_15_identifier[0] == TS2_ID_BYTE &&
          rx_bytes_i.sym1_link_number == PAD_SYMBOL && lane_match) begin
        if (!first_ts2_received) first_ts2_received = 1'b1;
        ts2_rx_count++;
        `uvm_info(name, $sformatf("Received matching TS2 (consecutive=%0d)", ts2_rx_count), UVM_HIGH)
      end
      else begin
        ts2_rx_count = 0;
      end

      if ((ts2_tx_count_complete >= MIN_TS2_TX_COMPLETE) && (ts2_rx_count >= CONSEC_TS2_COMPLETE)) begin
        bit barrier_ok;
        `uvm_info(name, "Polling.Configuration local condition met - waiting for EP", UVM_HIGH)
        rc_ready_polling_config = 1'b1;
        wait_for_partner_ready(ep_ready_polling_config, time'(2 * POLLING_TIMEOUT_MS * 1ms), barrier_ok);
        //NOT cleared here anymore - see race condition note where these flags are declared.

        if (!barrier_ok) begin
          `uvm_error(name, "Polling.Configuration: EP never reached readiness - returning to Detect")
          disable fork;
          next_state             = DETECT_ST;
          next_detect_substate   = DETECT_QUIET;
          ts2_tx_count_complete  = 0;
          ts2_rx_count           = 0;
          return;
        end

        `uvm_info(name, "Polling.Configuration completed successfully", UVM_LOW)
        disable fork;
        next_state            = CONFIG_ST;
        next_config_substate  = CFG_LINKWIDTH_START;
        ts2_tx_count_complete = 0;
        ts2_rx_count          = 0;
        return;
      end

      //Fixed: was CONFIG_TIMEOUT_MS (2ms) - genuinely too tight for this exchange.
      if (($time - start_time) >= (2 * POLLING_TIMEOUT_MS * 1ms)) begin
        `uvm_error(name, "Polling.Configuration Timeout")
        disable fork;
        next_state            = DETECT_ST;
        next_detect_substate  = DETECT_QUIET;
        ts2_tx_count_complete = 0;
        ts2_rx_count          = 0;
        return;
      end
    end
  endtask : run_polling_configuration

  // ---- L0: data phase ----

  //-------------------------------------------------------
  // Task: drive_symbol_stream
  //-------------------------------------------------------
  task automatic drive_symbol_stream(input bit [7:0] byte_stream [], input bit is_k_stream []);
    for (int s = 0; s < byte_stream.size(); s++) begin
      bit [9:0] encoded [0:PCIE_MAX_LANES-1];

      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
        encoded[l] = encode_8b10b_symbol(byte_stream[s], is_k_stream[s], lane_disparity[l]);
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
    end
  endtask : drive_symbol_stream

  //-------------------------------------------------------
  // Task: drive_skp
  //-------------------------------------------------------
  task automatic drive_skp();
    bit [7:0] stream [];
    bit       is_k   [];
    stream = new[4];
    is_k   = new[4];
    stream[0] = COM_SYMBOL; is_k[0] = 1'b1;
    stream[1] = SKP_SYMBOL; is_k[1] = 1'b1;
    stream[2] = SKP_SYMBOL; is_k[2] = 1'b1;
    stream[3] = SKP_SYMBOL; is_k[3] = 1'b1;
    drive_symbol_stream(stream, is_k);
  endtask : drive_skp

  //-------------------------------------------------------
  // Tasks: push_tlp / push_dllp / push_flit_payload
  //-------------------------------------------------------
  task automatic push_tlp(input byte_queue_t payload);
    tlp_tx_queue.push_back(payload);
  endtask : push_tlp

  task automatic push_dllp(input byte_queue_t payload);
    dllp_tx_queue.push_back(payload);
  endtask : push_dllp

  task automatic push_flit_payload(input flit_payload_t payload);
    flit_tx_queue.push_back(payload);
  endtask : push_flit_payload

  //-------------------------------------------------------
  // Task: drive_tlp
  //-------------------------------------------------------
  task automatic drive_tlp();
    byte_queue_t payload;
    bit [7:0]    stream [];
    bit          is_k   [];
    int          n;

    payload = tlp_tx_queue[0];
    void'(tlp_tx_queue.pop_front());
    n = payload.size();
    stream = new[n+2];
    is_k   = new[n+2];

    stream[0] = STP_TOKEN; is_k[0] = 1'b1;
    for (int i = 0; i < n; i++) begin
      stream[1+i] = payload[i];
      is_k[1+i]   = 1'b0;
    end
    stream[n+1] = END_TOKEN; is_k[n+1] = 1'b1;

    drive_symbol_stream(stream, is_k);
  endtask : drive_tlp

  //-------------------------------------------------------
  // Task: drive_dllp
  //-------------------------------------------------------
  task automatic drive_dllp();
    byte_queue_t payload;
    bit [7:0]    stream [];
    bit          is_k   [];
    int          n;

    payload = dllp_tx_queue[0];
    void'(dllp_tx_queue.pop_front());
    n = payload.size();
    stream = new[n+2];
    is_k   = new[n+2];

    stream[0] = SDP_TOKEN; is_k[0] = 1'b1;
    for (int i = 0; i < n; i++) begin
      stream[1+i] = payload[i];
      is_k[1+i]   = 1'b0;
    end
    stream[n+1] = END_TOKEN; is_k[n+1] = 1'b1;

    drive_symbol_stream(stream, is_k);
  endtask : drive_dllp

  //-------------------------------------------------------
  // Task: drive_flit
  //-------------------------------------------------------
  task automatic drive_flit();
    flit_payload_t payload;
    flit_t         flit;
    bit [(FLIT_BYTES*8)-1:0] flit_bits;
    bit [7:0] stream [];
    bit       is_k   [];

    payload = flit_tx_queue[0];
    void'(flit_tx_queue.pop_front());

    stream = new[FLIT_BYTES];
    is_k   = new[FLIT_BYTES];

    flit.tlp_payload = '0;
    for (int i = 0; i < FLIT_TLP_PAYLOAD_BYTES; i++)
      flit.tlp_payload[(i*8) +: 8] = payload[i];
    flit.dlp = '0;
    flit.crc = '0;
    flit.fec = '0;

    flit_bits = flit;
    for (int i = 0; i < FLIT_BYTES; i++) begin
      stream[i] = flit_bits[((FLIT_BYTES-1-i)*8) +: 8];
      is_k[i]   = 1'b0;
    end

    drive_symbol_stream(stream, is_k);
  endtask : drive_flit

  //-------------------------------------------------------
  // Task: sample_one_symbol
  //-------------------------------------------------------
  task automatic sample_one_symbol(output bit [7:0] byte_val, output bit is_k, output bit valid);
    bit [9:0] code;
    for (int b = 0; b < 10; b++) begin
      @(rcCb);
      code[b] = rcCb.RX_P[0];
    end
    decode_8b10b_symbol(code, rx_lane_disparity[0], byte_val, is_k, valid);
    rx_lane_disparity[0] = next_running_disparity(code, rx_lane_disparity[0]);
  endtask : sample_one_symbol

  //-------------------------------------------------------
  // Task: run_l0
  //-------------------------------------------------------
  task automatic run_l0();
    int unsigned consec_rx_errors;
    int unsigned skp_send_counter;
    realtime     last_legit_rx_time;

    int unsigned ts_candidate_symbol_pos;
    bit          ts_candidate_is_ts1;
    int unsigned consec_recovery_ts1_cnt;

    localparam int unsigned SKP_INTERVAL_SYMBOLS  = 128;
    localparam int unsigned MAX_CONSEC_RX_ERRORS  = 8;
    localparam realtime     L0_IDLE_RX_TIMEOUT    = 10ms;

    `uvm_info(name, "Entering L0", UVM_MEDIUM)

    current_state = L0_ST;

    current_rate                  = current_speed;
    directed_speed_change         = 1'b0;
    changed_speed_recovery        = 1'b0;
    successful_speed_negotiation  = 1'b0;

    transfer_mode = (current_speed >= FLIT_MODE_MANDATORY_FROM_GEN)
                    ? FLIT_MODE : rc_agent_cfg_h.preferred_transfer_mode;

    consec_rx_errors         = 0;
    skp_send_counter         = 0;
    last_legit_rx_time       = $realtime;
    ts_candidate_symbol_pos  = 0;
    ts_candidate_is_ts1      = 1'b0;
    consec_recovery_ts1_cnt  = 0;

    fork
      forever begin
        if (transfer_mode == FLIT_MODE) begin
          if (flit_tx_queue.size() > 0) drive_flit();
          else                          drive_idle();
        end
        else begin
          if (tlp_tx_queue.size() > 0) begin
            drive_tlp();
          end
          else if (dllp_tx_queue.size() > 0) begin
            drive_dllp();
          end
          else begin
            skp_send_counter++;
            if (skp_send_counter >= SKP_INTERVAL_SYMBOLS) begin
              drive_skp();
              skp_send_counter = 0;
            end
            else begin
              drive_idle();
            end
          end
        end
      end
    join_none

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

      if (ts_candidate_symbol_pos == 0) begin
        if (rx_valid && rx_is_k && rx_byte == COM_SYMBOL) begin
          ts_candidate_symbol_pos = 1;
          ts_candidate_is_ts1     = 1'b1;
        end
      end
      else begin
        if (ts_candidate_symbol_pos == 4) begin
          if (!(rx_valid && rx_byte[7])) begin
            ts_candidate_is_ts1 = 1'b0;
          end
        end

        if (ts_candidate_symbol_pos >= 6 && ts_candidate_symbol_pos <= 15) begin
          if (!(rx_valid && !rx_is_k && rx_byte == TS1_ID_BYTE)) begin
            ts_candidate_is_ts1 = 1'b0;
          end
        end

        ts_candidate_symbol_pos++;

        if (ts_candidate_symbol_pos > 15) begin
          consec_recovery_ts1_cnt = ts_candidate_is_ts1 ? consec_recovery_ts1_cnt + 1 : 0;
          ts_candidate_symbol_pos = 0;

          if (consec_recovery_ts1_cnt >= CONSEC_TS_REQUIRED) begin
            `uvm_info(name, $sformatf("L0: %0d consecutive qualified TS1 windows observed - partner left L0, following into Recovery",
                                       consec_recovery_ts1_cnt), UVM_LOW)
            disable fork;
            next_state           = RECOVERY_ST;
            next_recovery_reason = RECOVERY_REASON_PARTNER_INITIATED;
            return;
          end
        end
      end

      if (recovery_request) begin
        `uvm_info(name, "L0: directed Recovery request", UVM_LOW)
        recovery_request = 1'b0;
        disable fork;
        next_state           = RECOVERY_ST;
        next_recovery_reason = RECOVERY_REASON_DIRECTED;
        return;
      end

      if (current_speed != rc_agent_cfg_h.target_link_speed) begin
        directed_speed_change = 1'b1;
        `uvm_info(name, $sformatf("L0: directed_speed_change asserted (%s -> %s) - exiting L0 instantaneously, no handshake in L0 itself",
                                   current_speed.name(),
                                   rc_agent_cfg_h.target_link_speed.name()), UVM_LOW)
        disable fork;
        next_state           = RECOVERY_ST;
        next_recovery_reason = RECOVERY_REASON_SPEED_CHANGE;
        return;
      end

      if (consec_rx_errors >= MAX_CONSEC_RX_ERRORS) begin
        `uvm_warning(name, $sformatf("L0: %0d consecutive receive errors - entering Recovery",
                                      consec_rx_errors))
        disable fork;
        next_state           = RECOVERY_ST;
        next_recovery_reason = RECOVERY_REASON_ERROR_THRESHOLD;
        return;
      end

      if (($realtime - last_legit_rx_time) >= L0_IDLE_RX_TIMEOUT) begin
        `uvm_warning(name, "L0: no valid symbol received for too long - entering Recovery")
        disable fork;
        next_state           = RECOVERY_ST;
        next_recovery_reason = RECOVERY_REASON_IDLE_TIMEOUT;
        return;
      end
    end
  endtask : run_l0

  //-------------------------------------------------------
  //    RECOVERY   [NEW]
  //-------------------------------------------------------

  task automatic run_recovery_rcvr_lock();
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_rx_match_cnt;
    time                    start_time;
    bit                     lane_match;
    modified_ts_bytes_t     mod_tx_content;
    modified_ts_bytes_t     mod_rx_content;
    bit                     mod_rx_valid;

    `uvm_info(name, $sformatf("Entering Recovery.RcvrLock at %s, speed_change=%0d",
                               current_speed.name(), directed_speed_change), UVM_MEDIUM)

    current_state             = RECOVERY_ST;
    current_recovery_substate = RECOVERY_RCVR_LOCK;

    consec_rx_match_cnt = 0;
    start_time          = $time;

    // Gen3+ stays on Modified TS the whole time - doesn't drop back to standard
    // format just because another speed step is starting
    if (current_speed >= EQ_REQUIRED_MIN_GEN) begin
      mod_tx_content.id           = MOD_TS1_ID;
      mod_tx_content.link_number  = configured_link_number;
      mod_tx_content.lane_number  = PAD_SYMBOL;
      mod_tx_content.n_fts         = rc_agent_cfg_h.ntfs;
      mod_tx_content.data_rate_id = {directed_speed_change, 7'h3F};
      mod_tx_content.ec_byte       = EC_DONE;
      mod_tx_content.payload       = 8'h01; //Gen6 capabilities placeholder

      fork
        forever drive_modified_ts(mod_tx_content);
      join_none

      forever begin
        receive_modified_ts(mod_rx_content, mod_rx_valid);

        lane_match = (mod_rx_content.lane_number == configured_lane_number[0]);

        if (mod_rx_valid &&
            (mod_rx_content.id == MOD_TS1_ID || mod_rx_content.id == MOD_TS2_ID) &&
            mod_rx_content.data_rate_id[7] == directed_speed_change &&
            mod_rx_content.link_number == configured_link_number &&
            lane_match) begin
          consec_rx_match_cnt++;
        end
        else begin
          consec_rx_match_cnt = 0;
        end

        if (consec_rx_match_cnt >= CONSEC_TS_COUNT) begin
          `uvm_info(name, "Recovery.RcvrLock (Modified TS) complete - advancing to Recovery.RcvrCfg", UVM_HIGH)
          disable fork;
          next_state             = RECOVERY_ST;
          next_recovery_substate = RECOVERY_RCVR_CFG;
          return;
        end

        if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
          `uvm_error(name, "Recovery.RcvrLock (Modified TS) Timeout - returning to Detect")
          disable fork;
          next_state           = DETECT_ST;
          next_detect_substate = DETECT_QUIET;
          return;
        end
      end
    end
    else begin
      fork
        forever drive_ts(OS_TS1, configured_link_number, PAD_SYMBOL,
                          directed_speed_change,
                          rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                          rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                          rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b1);
      join_none

      forever begin
        receive_ts(rx_bytes, rx_lane_number, rx_valid);

        lane_match = 1'b1;
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != configured_lane_number[l]) lane_match = 1'b0;

        if (rx_valid &&
            (rx_bytes.sym6_15_identifier[0] == TS1_ID_BYTE || rx_bytes.sym6_15_identifier[0] == TS2_ID_BYTE) &&
            rx_bytes.sym4_data_rate_id[7] == directed_speed_change &&
            rx_bytes.sym1_link_number == configured_link_number &&
            lane_match) begin
          consec_rx_match_cnt++;
        end
        else begin
          consec_rx_match_cnt = 0;
        end

        if (consec_rx_match_cnt >= CONSEC_TS_COUNT) begin
          `uvm_info(name, "Recovery.RcvrLock complete - advancing to Recovery.RcvrCfg", UVM_HIGH)
          disable fork;
          next_state             = RECOVERY_ST;
          next_recovery_substate = RECOVERY_RCVR_CFG;
          return;
        end

        if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
          `uvm_error(name, "Recovery.RcvrLock Timeout - returning to Detect")
          disable fork;
          next_state           = DETECT_ST;
          next_detect_substate = DETECT_QUIET;
          return;
        end
      end
    end
  endtask : run_recovery_rcvr_lock

  task automatic run_recovery_rcvr_cfg();
    ts_ordered_set_bytes_t rx_bytes;
    bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
    bit                     rx_valid;
    int unsigned            consec_ts2_cnt;
    time                    start_time;
    bit                     need_another_speed_step;
    bit                     lane_match;
    modified_ts_bytes_t     mod_tx_content;
    modified_ts_bytes_t     mod_rx_content;
    bit                     mod_rx_valid;

    `uvm_info(name, $sformatf("Entering Recovery.RcvrCfg at %s, speed_change=%0d",
                               current_speed.name(), directed_speed_change), UVM_MEDIUM)

    current_state             = RECOVERY_ST;
    current_recovery_substate = RECOVERY_RCVR_CFG;

    consec_ts2_cnt = 0;
    start_time     = $time;

    if (current_speed >= EQ_REQUIRED_MIN_GEN) begin
      mod_tx_content.id           = MOD_TS2_ID;
      mod_tx_content.link_number  = configured_link_number;
      mod_tx_content.lane_number  = PAD_SYMBOL;
      mod_tx_content.n_fts         = rc_agent_cfg_h.ntfs;
      mod_tx_content.data_rate_id = {directed_speed_change, 7'h3F};
      mod_tx_content.ec_byte       = EC_DONE;
      mod_tx_content.payload       = 8'h01;

      fork
        forever drive_modified_ts(mod_tx_content);
      join_none

      forever begin
        receive_modified_ts(mod_rx_content, mod_rx_valid);

        lane_match = (mod_rx_content.lane_number == configured_lane_number[0]);

        if (mod_rx_valid && mod_rx_content.id == MOD_TS2_ID &&
            mod_rx_content.data_rate_id[7] == directed_speed_change &&
            mod_rx_content.link_number == configured_link_number &&
            lane_match) begin
          consec_ts2_cnt++;
        end
        else begin
          consec_ts2_cnt = 0;
        end

        if (consec_ts2_cnt >= CONSEC_TS_COUNT) begin
          disable fork;
          // already equalized for this speed (Phase 3 handles that) - just check
          // if another speed step is needed
          need_another_speed_step = (current_speed != rc_agent_cfg_h.target_link_speed);
          if (need_another_speed_step) begin
            `uvm_info(name, "Recovery.RcvrCfg (Modified TS) complete - another speed step needed, advancing to Recovery.Speed", UVM_HIGH)
            next_recovery_substate = RECOVERY_SPEED;
          end
          else begin
            `uvm_info(name, "Recovery.RcvrCfg (Modified TS) complete - advancing to Recovery.Idle", UVM_HIGH)
            next_recovery_substate = RECOVERY_IDLE;
          end
          next_state = RECOVERY_ST;
          return;
        end

        if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
          `uvm_error(name, "Recovery.RcvrCfg (Modified TS) Timeout - returning to Detect")
          disable fork;
          next_state           = DETECT_ST;
          next_detect_substate = DETECT_QUIET;
          return;
        end
      end
    end
    else begin
      fork
        forever drive_ts(OS_TS2, configured_link_number, PAD_SYMBOL,
                          directed_speed_change,
                          rc_agent_cfg_h.default_autonomous_change, rc_agent_cfg_h.default_elbc,
                          rc_agent_cfg_h.default_no_scrambling, rc_agent_cfg_h.default_loopback,
                          rc_agent_cfg_h.default_disable_link, rc_agent_cfg_h.default_hot_reset, 1'b1);
      join_none

      forever begin
        receive_ts(rx_bytes, rx_lane_number, rx_valid);

        lane_match = 1'b1;
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          if (rx_lane_number[l] != configured_lane_number[l]) lane_match = 1'b0;

        if (rx_valid && rx_bytes.sym6_15_identifier[0] == TS2_ID_BYTE &&
            rx_bytes.sym4_data_rate_id[7] == directed_speed_change &&
            rx_bytes.sym1_link_number == configured_link_number &&
            lane_match) begin
          consec_ts2_cnt++;
        end
        else begin
          consec_ts2_cnt = 0;
        end

        if (consec_ts2_cnt >= CONSEC_TS_COUNT) begin
          disable fork;

          need_another_speed_step = (current_speed != rc_agent_cfg_h.target_link_speed);

          if (need_another_speed_step) begin
            `uvm_info(name, "Recovery.RcvrCfg complete - another speed step needed, advancing to Recovery.Speed", UVM_HIGH)
            next_state             = RECOVERY_ST;
            next_recovery_substate = RECOVERY_SPEED;
          end
          else if (current_speed >= EQ_REQUIRED_MIN_GEN && !equalization_done_this_speed) begin
            `uvm_info(name, "Recovery.RcvrCfg complete - target speed reached, equalization required - advancing to Recovery.Equalization Phase 0", UVM_HIGH)
            next_state             = RECOVERY_ST;
            next_recovery_substate = RECOVERY_EQ_PHASE0;
          end
          else begin
            `uvm_info(name, "Recovery.RcvrCfg complete - advancing to Recovery.Idle", UVM_HIGH)
            next_state             = RECOVERY_ST;
            next_recovery_substate = RECOVERY_IDLE;
          end
          return;
        end

        if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
          `uvm_error(name, "Recovery.RcvrCfg Timeout - returning to Detect")
          disable fork;
          next_state           = DETECT_ST;
          next_detect_substate = DETECT_QUIET;
          return;
        end
      end
    end
  endtask : run_recovery_rcvr_cfg

  //-------------------------------------------------------
  // Task: run_recovery_speed
  //-------------------------------------------------------
  task automatic run_recovery_speed();
    int unsigned seq_idx;
    bit          found_idx;

    `uvm_info(name, $sformatf("Entering Recovery.Speed (%s -> next step)", current_speed.name()), UVM_MEDIUM)

    current_state             = RECOVERY_ST;
    current_recovery_substate = RECOVERY_SPEED;

    if (!PLL_LOCK_ASSUMED) begin
      `uvm_error(name, "PLL_LOCK_ASSUMED=0 - no analog PHY rate-switch model exists in this file to fall back to")
      next_state           = DETECT_ST;
      next_detect_substate = DETECT_QUIET;
      return;
    end

    found_idx = 1'b0;
    for (int i = 0; i < $size(SPEED_UPGRADE_SEQUENCE); i++) begin
      if (SPEED_UPGRADE_SEQUENCE[i] == current_speed) begin
        seq_idx   = i;
        found_idx = 1'b1;
      end
    end

    if (found_idx && (seq_idx + 1) < $size(SPEED_UPGRADE_SEQUENCE)) begin
      current_speed = SPEED_UPGRADE_SEQUENCE[seq_idx + 1];
    end

    directed_speed_change        = 1'b0;
    changed_speed_recovery       = 1'b1;
    current_rate                  = current_speed;
    equalization_done_this_speed = 1'b0;
    symbol_lock_acquired         = 1'b0;

    if (current_speed == rc_agent_cfg_h.target_link_speed) begin
      successful_speed_negotiation = 1'b1;
    end

    `uvm_info(name, $sformatf("Recovery.Speed complete - now at %s, speed_change cleared - returning to Recovery.RcvrLock",
                               current_speed.name()), UVM_LOW)

    next_state             = RECOVERY_ST;
    next_recovery_substate = RECOVERY_RCVR_LOCK;
  endtask : run_recovery_speed

  // Phase 0 (EC=01b): RC sends a Tx preset, EP must echo it back before we move on
  task automatic run_recovery_eq_phase0();
    modified_ts_bytes_t tx_content;
    modified_ts_bytes_t rx_content;
    bit                 rx_valid;
    int unsigned        consec_match_cnt;
    time                start_time;

    `uvm_info(name, "Entering Recovery.Equalization Phase 0 (preset exchange)", UVM_MEDIUM)

    current_state             = RECOVERY_ST;
    current_recovery_substate = RECOVERY_EQ_PHASE0;

    // fixed default preset (P5) - real selection is BER-driven, not modeled here
    negotiated_tx_preset = 8'h53;

    consec_match_cnt = 0;
    start_time       = $time;

    tx_content.id           = MOD_TS2_ID;
    tx_content.link_number  = configured_link_number;
    tx_content.lane_number  = PAD_SYMBOL;
    tx_content.n_fts         = rc_agent_cfg_h.ntfs;
    tx_content.data_rate_id = 8'h3F; //SC=0 - speed change already completed by this point
    tx_content.ec_byte       = EC_PHASE0_1;
    tx_content.payload       = negotiated_tx_preset;

    fork
      forever drive_modified_ts(tx_content);
    join_none

    forever begin
      receive_modified_ts(rx_content, rx_valid);

      if (rx_valid && rx_content.id == MOD_TS1_ID &&
          rx_content.ec_byte == EC_PHASE0_1 &&
          rx_content.payload == negotiated_tx_preset &&
          rx_content.link_number == configured_link_number) begin
        consec_match_cnt++;
      end
      else begin
        consec_match_cnt = 0;
      end

      if (consec_match_cnt >= CONSEC_TS_REQUIRED) begin
        `uvm_info(name, "Equalization Phase 0 complete - preset echoed correctly - advancing to Phase 1", UVM_HIGH)
        disable fork;
        next_state             = RECOVERY_ST;
        next_recovery_substate = RECOVERY_EQ_PHASE1;
        return;
      end

      if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
        `uvm_error(name, "Equalization Phase 0 Timeout - returning to Detect")
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_recovery_eq_phase0

  // Phase 1 (EC=01b, same as Phase 0): FS/LF calibration, both sides now on TS1
  task automatic run_recovery_eq_phase1();
    modified_ts_bytes_t tx_content;
    modified_ts_bytes_t rx_content;
    bit                 rx_valid;
    int unsigned        consec_match_cnt;
    time                start_time;

    `uvm_info(name, "Entering Recovery.Equalization Phase 1 (FS/LF exchange)", UVM_MEDIUM)

    current_state             = RECOVERY_ST;
    current_recovery_substate = RECOVERY_EQ_PHASE1;

    consec_match_cnt = 0;
    start_time       = $time;

    tx_content.id           = MOD_TS1_ID;
    tx_content.link_number  = configured_link_number;
    tx_content.lane_number  = PAD_SYMBOL;
    tx_content.n_fts         = rc_agent_cfg_h.ntfs;
    tx_content.data_rate_id = 8'h3F;
    tx_content.ec_byte       = EC_PHASE0_1;
    tx_content.payload       = 8'hF4; //FS/LF representative value - real full-swing/low-freq
                                       //capability computation not modeled here

    fork
      forever drive_modified_ts(tx_content);
    join_none

    forever begin
      receive_modified_ts(rx_content, rx_valid);

      if (rx_valid && rx_content.id == MOD_TS1_ID &&
          rx_content.ec_byte == EC_PHASE0_1 &&
          rx_content.link_number == configured_link_number) begin
        consec_match_cnt++;
      end
      else begin
        consec_match_cnt = 0;
      end

      if (consec_match_cnt >= CONSEC_TS_COUNT) begin
        `uvm_info(name, "Equalization Phase 1 complete - advancing to Phase 2", UVM_HIGH)
        disable fork;
        next_state             = RECOVERY_ST;
        next_recovery_substate = RECOVERY_EQ_PHASE2;
        return;
      end

      if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
        `uvm_error(name, "Equalization Phase 1 Timeout - returning to Detect")
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_recovery_eq_phase1

  // Phase 2 (EC=10b): RC adjusts EP's Tx coefficients - bounded rounds stand in
  // for a real BER-driven convergence loop
  task automatic run_recovery_eq_phase2();
    modified_ts_bytes_t tx_content;
    modified_ts_bytes_t rx_content;
    bit                 rx_valid;
    int unsigned        consec_match_cnt;
    time                start_time;

    `uvm_info(name, "Entering Recovery.Equalization Phase 2 (RC adjusts EP Tx)", UVM_MEDIUM)

    current_state             = RECOVERY_ST;
    current_recovery_substate = RECOVERY_EQ_PHASE2;

    consec_match_cnt = 0;
    start_time       = $time;

    tx_content.id           = MOD_TS1_ID;
    tx_content.link_number  = configured_link_number;
    tx_content.lane_number  = PAD_SYMBOL;
    tx_content.n_fts         = rc_agent_cfg_h.ntfs;
    tx_content.data_rate_id = 8'h3F;
    tx_content.ec_byte       = EC_PHASE2;
    tx_content.payload       = 8'h49; //representative coefficient request (Inc/Dec/Inc) -
                                       //real per-iteration values driven by BER feedback,
                                       //not modeled here

    fork
      forever drive_modified_ts(tx_content);
    join_none

    forever begin
      receive_modified_ts(rx_content, rx_valid);

      // accepts any coefficient status EP reports for Phase 2 - value itself
      // isn't checked since there's no real BER model to validate against
      if (rx_valid && rx_content.id == MOD_TS1_ID &&
          rx_content.ec_byte == EC_PHASE2 &&
          rx_content.link_number == configured_link_number) begin
        consec_match_cnt++;
      end
      else begin
        consec_match_cnt = 0;
      end

      if (consec_match_cnt >= CONSEC_TS_COUNT) begin
        `uvm_info(name, "Equalization Phase 2 complete (bounded round count reached) - advancing to Phase 3", UVM_HIGH)
        disable fork;
        next_state             = RECOVERY_ST;
        next_recovery_substate = RECOVERY_EQ_PHASE3;
        return;
      end

      if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
        `uvm_error(name, "Equalization Phase 2 Timeout - returning to Detect")
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_recovery_eq_phase2

  // Phase 3 (EC=11b): roles flip, EP now adjusts RC's Tx coefficients
  task automatic run_recovery_eq_phase3();
    modified_ts_bytes_t tx_content;
    modified_ts_bytes_t rx_content;
    bit                 rx_valid;
    int unsigned        consec_match_cnt;
    time                start_time;

    `uvm_info(name, "Entering Recovery.Equalization Phase 3 (EP adjusts RC Tx)", UVM_MEDIUM)

    current_state             = RECOVERY_ST;
    current_recovery_substate = RECOVERY_EQ_PHASE3;

    consec_match_cnt = 0;
    start_time       = $time;

    tx_content.id           = MOD_TS1_ID;
    tx_content.link_number  = configured_link_number;
    tx_content.lane_number  = PAD_SYMBOL;
    tx_content.n_fts         = rc_agent_cfg_h.ntfs;
    tx_content.data_rate_id = 8'h3F;
    tx_content.ec_byte       = EC_PHASE3;
    tx_content.payload       = 8'h07; //RC's own coefficient status, reported for EP to
                                       //evaluate - representative value, no real BER model

    fork
      forever drive_modified_ts(tx_content);
    join_none

    forever begin
      receive_modified_ts(rx_content, rx_valid);

      if (rx_valid && rx_content.id == MOD_TS1_ID &&
          rx_content.ec_byte == EC_PHASE3 &&
          rx_content.link_number == configured_link_number) begin
        consec_match_cnt++;
      end
      else begin
        consec_match_cnt = 0;
      end

      if (consec_match_cnt >= CONSEC_TS_COUNT) begin
        `uvm_info(name, "Equalization Phase 3 complete - EQUALIZATION COMPLETE - EC drops to 00b, advancing to Recovery.RcvrLock",
                  UVM_LOW)
        disable fork;
        equalization_done_this_speed = 1'b1;
        next_state             = RECOVERY_ST;
        next_recovery_substate = RECOVERY_RCVR_LOCK;
        return;
      end

      if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
        `uvm_error(name, "Equalization Phase 3 Timeout - returning to Detect")
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_recovery_eq_phase3

  task automatic run_recovery_idle();
    bit [7:0]    rx_byte [0:PCIE_MAX_LANES-1];
    bit          rx_ok   [0:PCIE_MAX_LANES-1];
    bit          all_lanes_idle;
    int unsigned consec_idle_cnt;
    int unsigned idle_attempt_cnt;
    int unsigned local_idle_tx_count;

    `uvm_info(name, "Entering Recovery.Idle", UVM_MEDIUM)

    current_state             = RECOVERY_ST;
    current_recovery_substate = RECOVERY_IDLE;

    consec_idle_cnt     = 0;
    idle_attempt_cnt     = 0;
    local_idle_tx_count  = 0;

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
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        if (!(rx_ok[l] && (rx_byte[l] == IDLE_SYMBOL))) all_lanes_idle = 1'b0;

      consec_idle_cnt = all_lanes_idle ? consec_idle_cnt + 1 : 0;

      if ((consec_idle_cnt >= MIN_IDLE_RX) && (local_idle_tx_count >= MIN_IDLE_TX)) begin
        `uvm_info(name, "Recovery.Idle completed - returning to L0", UVM_LOW)
        disable fork;
        next_state = L0_ST;
        return;
      end

      if (idle_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_error(name, "Recovery.Idle Timeout - returning to Detect")
        disable fork;
        next_state           = DETECT_ST;
        next_detect_substate = DETECT_QUIET;
        return;
      end
    end
  endtask : run_recovery_idle

endinterface : pcie_phy_rc_driver_bfm

`endif
