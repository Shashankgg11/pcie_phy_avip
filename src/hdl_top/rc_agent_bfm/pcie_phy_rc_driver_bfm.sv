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

  //-------------------------------------------------------
  // Speed-change tracking, matching the reference state table exactly:
  //   directed_speed_change  - RC sets this internally; THE trigger. EP never sets this
  //                            independently - only RC (the initiator) decides to climb.
  //   current_rate           - snapshot of current_speed at the moment L0 was entered.
  //   changed_speed_recovery / successful_speed_negotiation - both stay 0 here; only
  //                            Recovery.Speed (not yet built) sets these once the actual
  //                            TS1-with-speed_change-bit handshake completes.
  //-------------------------------------------------------
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

  //-------------------------------------------------------
  // Variable: symbol_lock_acquired
  // Real symbol/bit-boundary alignment, once found, persists for the rest of this run until
  // an explicit reset (default_values() clears it back to 0). Our own drive_ts()/drive_idle()
  // serialize every active lane bit-for-bit in lockstep (same clock edge, same bit
  // position) - the partner side models the same symmetrically - so finding alignment via
  // lane 0 alone is sufficient; no need to search each lane independently.
  //-------------------------------------------------------
  bit symbol_lock_acquired;

  //-------------------------------------------------------
  // L0 data-phase queues. NOTE: no full sequencer/item integration exists for the data
  // phase yet - a test/sequence can call push_tlp()/push_dllp()/push_flit_payload()
  // directly on this driver_bfm's virtual interface handle to enqueue real data for
  // run_l0() to send.
  //-------------------------------------------------------
  typedef bit [7:0] byte_queue_t [$];
  typedef bit [7:0] flit_payload_t [0:FLIT_TLP_PAYLOAD_BYTES-1];

  byte_queue_t    tlp_tx_queue  [$];
  byte_queue_t    dllp_tx_queue [$];
  flit_payload_t  flit_tx_queue [$];

  //-------------------------------------------------------
  // LTSSM state-tracking variables - persistent module-level vars (not task outputs),
  // matching the convention already used throughout this file.
  //-------------------------------------------------------
  ltssm_state_e      current_state;
  ltssm_state_e      next_state;
  recovery_reason_e  next_recovery_reason;
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
    tlp_tx_queue.delete();
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
  // Real comma/symbol-boundary detection - what receive_ts() was missing entirely before.
  // Shifts RX_P in one bit at a time per active lane, checking after EVERY new bit whether
  // lane 0's current 10-bit window is a genuine COM (either disparity variant - COM is
  // unique among all 8b/10b codes, so this check alone is enough to prove real alignment,
  // no prior disparity assumption needed). Lane 0 is the trigger; all active lanes' windows
  // are tracked in parallel so once lock is confirmed, every lane's already-aligned symbol-0
  // content is available immediately - no lane needs its own independent search, since this
  // driver's own TX side serializes every lane bit-for-bit in lockstep, and the partner does
  // the same.
  //
  // Once found: sets symbol_lock_acquired, and derives each lane's ACTUAL rx_lane_disparity
  // directly from which COM variant that lane's window shows (K_COM_N implies the sender's
  // disparity was RD_MINUS going into this symbol; K_COM_P implies RD_PLUS) - not just
  // copied from lane 0, since each lane's disparity is tracked independently in principle.
  //-------------------------------------------------------
  task automatic acquire_symbol_lock(output bit [9:0] locked_code [0:PCIE_MAX_LANES-1]);
    bit [9:0] window [0:PCIE_MAX_LANES-1];

    foreach (window[l]) window[l] = '0;

    forever begin
      @(rcCb);
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        window[l] = {rcCb.RX_P[l], window[l][9:1]};

      if (window[0] inside {K_COM_P, K_COM_N}) begin
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
          locked_code[l] = window[l];
          if (window[l] == K_COM_N)      rx_lane_disparity[l] = RD_MINUS;
          else if (window[l] == K_COM_P) rx_lane_disparity[l] = RD_PLUS;
          //else: this lane's window wasn't a valid COM even though lane 0's was - real
          //hardware would flag this as a lane-to-lane skew/error; left as-is here (disparity
          //unchanged) rather than guessing, since that's a genuine anomaly worth surfacing
          //via the normal decode_8b10b_symbol() valid-check that runs right after this
          //returns, not silently patched over here.
        end
        symbol_lock_acquired = 1'b1;
        `uvm_info(name, "Symbol lock acquired (real COM found on lane 0)", UVM_MEDIUM)
        return;
      end
    end
  endtask : acquire_symbol_lock

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

    //-------------------------------------------------------
    // One-time bootstrap: if we've never found real symbol alignment yet, find it now by
    // searching for a genuine COM - this IS symbol 0, decoded directly from the search
    // result rather than re-sampled (re-sampling would consume symbol 1's bits instead).
    // Only needed once - every subsequent receive_ts() call in this run skips straight to
    // the normal fixed-window sampling below, since alignment persists once found.
    //-------------------------------------------------------
    if (!symbol_lock_acquired) begin
      bit [9:0] locked_code [0:PCIE_MAX_LANES-1];
      acquire_symbol_lock(locked_code);

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
  endtask : receive_ts

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

    for (int b = 0; b < 10; b++) begin
      @(rcCb);
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        rx_encoded[l][b] = rcCb.RX_P[l];
    end

    for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
      bit decoded_is_k;
      decode_8b10b_symbol(rx_encoded[l], rx_lane_disparity[l], rx_byte[l], decoded_is_k, rx_ok[l]);
      rx_lane_disparity[l] = next_running_disparity(rx_encoded[l], rx_lane_disparity[l]);
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

  //--------------------------------------------------------------------------------------------------------------------------------- 
  //    DETECT
  //---------------------------------------------------------------------------------------------------------------------------------
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

  //--------------------------------------------------------------------------------------------------------------------------------- 
  //    CONFIGURATION.LINKWIDTH
  //---------------------------------------------------------------------------------------------------------------------------------
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
  //    CONFIGURATION.LANENUM    [NEW]
  //---------------------------------------------------------------------------------------------------------------------------------
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

  //--------------------------------------------------------------------------------------------------------------------------------- 
  //    CONFIGURATION.COMPLETE / IDLE    [NEW]
  //---------------------------------------------------------------------------------------------------------------------------------
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

    `uvm_info(name, "Entering Configuration.Idle", UVM_MEDIUM)

    current_state           = CONFIG_ST;
    current_config_substate = CFG_IDLE;

    idle_rx_count     = 0;
    idle_tx_count     = 0;
    idle_attempt_cnt  = 0;

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
        `uvm_info(name, "Configuration.Idle completed - Link Up (L0)", UVM_LOW)
        disable fork;
        next_state    = L0_ST;
        idle_tx_count = 0;
        idle_rx_count = 0;
        return;
      end

      if (idle_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
        `uvm_error(name, "Configuration.Idle Timeout")
        disable fork;
        //NOTE: Recovery states (RECOVERY_RCVR_LOCK etc.) don't exist in this file yet -
        //returning to Detect for now rather than a dead-end Recovery jump. Revisit once
        //Recovery is built out.
        next_state            = DETECT_ST;
        next_detect_substate  = DETECT_QUIET;
        idle_tx_count = 0;
        idle_rx_count = 0;
        return;
      end
    end
  endtask : run_configuration_idle

  //--------------------------------------------------------------------------------------------------------------------------------- 
  //    POLLING ACTIVE   [FIXED - real RX loop added, timeout units fixed]
  //---------------------------------------------------------------------------------------------------------------------------------
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

      //Throttled: full detail every single reception would be ~1024 lines per side just for
      //this one state (ts1_tx_count must reach TS1_1024_COUNT regardless of match count) -
      //print at UVM_LOW only on the first reception and every 128th after, so a default run
      //shows proof of genuine exchange without flooding. Raise verbosity to UVM_HIGH to see
      //every single one.
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

  //--------------------------------------------------------------------------------------------------------------------------------- 
  //    POLLING COMPLIANCE   [NEW]
  //---------------------------------------------------------------------------------------------------------------------------------
  // No logical exit condition of its own per spec - sends a Compliance Pattern
  // indefinitely; only leaves via an external event, modeled here via the package-global
  // exit_compliance_req flag (set externally), consumed (reset to 0) on exit.
  //---------------------------------------------------------------------------------------------------------------------------------
  task automatic run_polling_compliance();
    int unsigned compliance_pattern_count;

    `uvm_info(name, "Entering Polling.Compliance", UVM_MEDIUM)

    current_state             = POLLING_ST;
    current_polling_substate  = POLLING_COMPLIANCE;
    compliance_pattern_count  = 0;

    forever begin
      //Placeholder framing: a real Compliance Pattern is a fixed scrambled bit sequence,
      //not a TS - driven here as tagged TS1-shaped send purely for symbol-level timing
      //until a dedicated compliance-pattern generator exists.
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

  //--------------------------------------------------------------------------------------------------------------------------------- 
  //    POLLING CONFIGURE   [FIXED - real RX loop added, timeout units fixed]
  //---------------------------------------------------------------------------------------------------------------------------------
  task automatic run_polling_configuration();
    time start_time;
    bit  first_ts2_received;

    `uvm_info(name, "Entering Polling.Configuration", UVM_MEDIUM)

    current_state             = POLLING_ST;
    current_polling_substate  = POLLING_CONFIG;

    ts2_tx_count_complete = 0;
    ts2_rx_count          = 0;
    first_ts2_received     = 1'b0;
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

      if (rx_valid_i && rx_bytes_i.sym6_15_identifier[0] == TS2_ID_BYTE) begin
        if (!first_ts2_received) first_ts2_received = 1'b1;
        ts2_rx_count++;
        `uvm_info(name, $sformatf("Received matching TS2 (rx_count=%0d)", ts2_rx_count), UVM_HIGH)
      end

      if ((ts2_tx_count_complete >= MIN_TS2_TX_COMPLETE) && (ts2_rx_count >= CONSEC_TS_COUNT)) begin
        `uvm_info(name, "Polling.Configuration completed successfully", UVM_LOW)
        disable fork;
        next_state            = CONFIG_ST;
        next_config_substate  = CFG_LINKWIDTH_START;
        ts2_tx_count_complete = 0;
        ts2_rx_count          = 0;
        return;
      end

      if (($time - start_time) >= (CONFIG_TIMEOUT_MS * 1ms)) begin
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

  //--------------------------------------------------------------------------------------------------------------------------------- 
  //    L0 - data phase   [NEW]
  //---------------------------------------------------------------------------------------------------------------------------------
  // Scope/honesty notes, read before using:
  //  1. encode_8b10b_symbol()/decode_8b10b_symbol() (used below via drive_symbol_stream) are
  //     genuinely correct only for GEN1/GEN2 (real 8b/10b line coding). GEN3-GEN5 use
  //     128b/130b block encoding and GEN6 FLIT_MODE uses yet another scheme - neither exists
  //     in this file. What's built here is LOGICALLY/protocol-content correct (right framing,
  //     right token bytes, right Flit layout) at every speed, but only genuinely bit-accurate
  //     on the wire at GEN1/GEN2.
  //  2. drive_flit()'s dlp/crc/fec fields are left as placeholder zeros - real sequence
  //     number/ack tracking and CRC/FEC computation don't exist here yet.
  //  3. No full sequencer/item integration for data exists yet - see push_tlp() etc. above.
  //---------------------------------------------------------------------------------------------------------------------------------

  //-------------------------------------------------------
  // Task: drive_symbol_stream
  // Shared TX helper for everything in this L0 section - encodes and serializes an arbitrary
  // byte stream, driving the SAME byte on every active lane each symbol-time (unlike drive_ts,
  // none of SKP/TLP/DLLP/Flit content is per-lane-numbered).
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
  // Classic 4-symbol SKIP Ordered Set (COM + 3xSKP) for periodic clock-tolerance
  // compensation in L0. Real higher-gen block-based SKP framing differs - see scope note.
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
  // Test/sequence-facing hooks - call these on the virtual interface handle to enqueue real
  // data for run_l0() to drain.
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
  // NON_FLIT_MODE only. STP_TOKEN + payload + END_TOKEN framing.
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
  // NON_FLIT_MODE only. SDP_TOKEN + payload + END_TOKEN framing. Real DLLPs have a fixed
  // short length and a CRC16 - simplified here to whatever payload was pushed, no CRC.
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
  // FLIT_MODE only (mandatory GEN6, optional lower gens if negotiated). Builds one flit_t
  // (dlp/crc/fec left as placeholder zeros), flattens it to a 256-byte stream, all D-codes
  // (real Flits aren't STP/SDP/END-token-framed - fixed size/cadence instead).
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
    flit.dlp = '0; //TODO: real sequence-number/ack fields
    flit.crc = '0; //TODO: real CRC
    flit.fec = '0; //TODO: real FEC

    flit_bits = flit;
    for (int i = 0; i < FLIT_BYTES; i++) begin
      stream[i] = flit_bits[((FLIT_BYTES-1-i)*8) +: 8];
      is_k[i]   = 1'b0;
    end

    drive_symbol_stream(stream, is_k);
  endtask : drive_flit

  //-------------------------------------------------------
  // Task: sample_one_symbol
  // Lightweight RX helper for run_l0()'s error/idle tracking - lane 0 only. Assumes
  // symbol_lock_acquired is already true by the time L0 is reached (true in the real flow -
  // receive_ts() during Polling/Configuration establishes lock well before L0).
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
  // Drains pending data (Flit if FLIT_MODE, else TLP then DLLP priority), sends periodic SKP
  // OS when idle, and watches RX for 5 REAL exit conditions to Recovery:
  //   1. recovery_request (directed, test/sequence-driven)
  //   2. current_speed != target_link_speed (climbing per SPEED_UPGRADE_SEQUENCE) - sets
  //      directed_speed_change=1 and exits INSTANTANEOUSLY, no TS sent while still in L0
  //   3. Partner-initiated: CONSEC_TS_REQUIRED consecutive QUALIFIED TS1 windows observed
  //      (not a naive single-COM check - requires the identifier bytes to genuinely match
  //      TS1_ID_BYTE too, same discipline as every other transition in this file)
  //   4. MAX_CONSEC_RX_ERRORS consecutive decode failures
  //   5. L0_IDLE_RX_TIMEOUT elapsed with no valid symbol received at all
  //-------------------------------------------------------
  task automatic run_l0();
    int unsigned consec_rx_errors;
    int unsigned skp_send_counter;
    realtime     last_legit_rx_time;

    //Qualification tracker for RECOVERY_REASON_PARTNER_INITIATED - operates on the SAME
    //single-symbol stream sample_one_symbol() already provides, tracking position within a
    //candidate 16-symbol TS window incrementally (does NOT call receive_ts() - that task
    //independently samples its own 16 symbols, which would desync alignment by one position
    //if called after already peeking one symbol here).
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
          else                          drive_idle(); //TODO: real logical-idle-flit content
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

      //-------------------------------------------------------
      // Partner-initiated Recovery qualification tracker - see task header note above.
      //-------------------------------------------------------
      if (ts_candidate_symbol_pos == 0) begin
        if (rx_valid && rx_is_k && rx_byte == COM_SYMBOL) begin
          ts_candidate_symbol_pos = 1;
          ts_candidate_is_ts1     = 1'b1;
        end
      end
      else begin
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

endinterface : pcie_phy_rc_driver_bfm

`endif
