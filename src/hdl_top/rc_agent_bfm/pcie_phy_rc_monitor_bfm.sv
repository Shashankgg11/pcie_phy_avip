`ifndef PCIE_PHY_RC_MONITOR_BFM_INCLUDED_
`define PCIE_PHY_RC_MONITOR_BFM_INCLUDED_
//-------------------------------------------------------
// Importing global package
//-------------------------------------------------------
import pcie_phy_pkg::*;
interface pcie_phy_rc_monitor_bfm(input logic pclk,
                                   input logic preset_n,
                                   input logic [PCIE_MAX_LANES-1:0] RX_P,
                                   input logic [PCIE_MAX_LANES-1:0] RX_N
                                  );
  //-------------------------------------------------------
  // Importing UVM Package
  //-------------------------------------------------------
  import uvm_pkg::*;
  import pcie_phy_pkg::*;
  import pcie_phy_rc_pkg::*;
  string name = "PCIE_PHY_RC_MONITOR_BFM";
  // RC agent configuration handle
  pcie_phy_rc_agent_config rc_agent_cfg_h;
  initial begin
    `uvm_info(name, $sformatf(name), UVM_LOW)
  end
  clocking rcMonCb @(posedge pclk);
    default input #1step;
    input RX_P, RX_N;
    input preset_n;
  endclocking
  //-------------------------------------------------------
  // Local RX-side variables
  //-------------------------------------------------------
  pcie_gen_e          current_speed;
  bit [7:0]            configured_link_number;
  bit [7:0]            configured_lane_number [0:PCIE_MAX_LANES-1];
  int unsigned        ts1_rx_count;
  int unsigned        ts2_rx_count_complete;
  int unsigned        idle_rx_count;
  int unsigned        skp_rx_count;
  running_disparity_e lane_disparity [0:PCIE_MAX_LANES-1];
  //-------------------------------------------------------
  // Task: wait_for_reset
  //-------------------------------------------------------
  task wait_for_reset();
    @(negedge preset_n);
    `uvm_info(name, "SYSTEM RESET DETECTED IN MONITOR", UVM_HIGH)
    default_values();
    @(posedge preset_n);
    `uvm_info(name, "SYSTEM RESET DEACTIVATED IN MONITOR", UVM_HIGH)
  endtask : wait_for_reset
  //-------------------------------------------------------
  // Task: default_values
  //-------------------------------------------------------
  task default_values();
    foreach (configured_lane_number[l]) configured_lane_number[l] = PAD_SYMBOL;
    foreach (lane_disparity[l]) begin
      if (rc_agent_cfg_h != null)
        lane_disparity[l] = rc_agent_cfg_h.initial_disparity;
      else
        lane_disparity[l] = RD_MINUS;
    end
    configured_link_number = PAD_SYMBOL;
    current_speed          = GEN1;
    ts1_rx_count           = 0;
    ts2_rx_count_complete  = 0;
    idle_rx_count          = 0;
    skp_rx_count           = 0;
  endtask : default_values
 
  //-------------------------------------------------------
  // Function: decode_8b10b_symbol
  //-------------------------------------------------------
  function automatic bit [7:0] decode_8b10b_symbol(input  bit [9:0] raw_10b,
                                                   output bit       is_k_code,
                                                   output bit       code_err);
    code_err  = 1'b0;
    is_k_code = 1'b0;
    case (raw_10b)
      K_COM_N, K_COM_P: begin decode_8b10b_symbol = COM_SYMBOL; is_k_code = 1'b1; end
      K_PAD_N, K_PAD_P: begin decode_8b10b_symbol = PAD_SYMBOL; is_k_code = 1'b1; end
      K_SKP_N, K_SKP_P: begin decode_8b10b_symbol = SKP_SYMBOL; is_k_code = 1'b1; end
      K_STP_N, K_STP_P: begin decode_8b10b_symbol = STP_TOKEN;  is_k_code = 1'b1; end
      K_SDP_N, K_SDP_P: begin decode_8b10b_symbol = SDP_TOKEN;  is_k_code = 1'b1; end
      K_END_N, K_END_P: begin decode_8b10b_symbol = END_TOKEN;  is_k_code = 1'b1; end
      K_EDB_N, K_EDB_P: begin decode_8b10b_symbol = EDB_TOKEN;  is_k_code = 1'b1; end
      K_EIE_N, K_EIE_P: begin decode_8b10b_symbol = EIE_SYM;    is_k_code = 1'b1; end
      default: begin
        bit found;
        found = 1'b0;
        for (int i = 0; i < 256; i++) begin
          if (D_NEG_DISP[i] == raw_10b || D_POS_DISP[i] == raw_10b) begin
            decode_8b10b_symbol = i[7:0];
            found = 1'b1;
            break;
          end
        end
        if (!found) begin
          code_err = 1'b1;
          decode_8b10b_symbol = 8'hXX;
        end
      end
    endcase
  endfunction : decode_8b10b_symbol
 
  //-------------------------------------------------------
  // Function: check_running_disparity
  //-------------------------------------------------------
  function automatic bit check_running_disparity(input bit [9:0]           symbol10b,
                                                 input running_disparity_e cur_rd);
    int ones;
    ones = $countones(symbol10b);
    if (cur_rd == RD_MINUS && ones < 5) return 1'b0; // Disparity Error
    if (cur_rd == RD_PLUS  && ones > 5) return 1'b0; // Disparity Error
    return 1'b1; // Valid
  endfunction : check_running_disparity
 
  //-------------------------------------------------------
  // Function: next_running_disparity
  //-------------------------------------------------------
  function automatic running_disparity_e next_running_disparity(input bit [9:0]           encoded_symbol,
                                                                input running_disparity_e cur_rd);
    int ones;
    ones = $countones(encoded_symbol);
    if (ones > 5)      next_running_disparity = RD_PLUS;
    else if (ones < 5) next_running_disparity = RD_MINUS;
    else               next_running_disparity = cur_rd;
  endfunction : next_running_disparity
 
  //-------------------------------------------------------
  // Task: sample_symbol_10b
  //-------------------------------------------------------
  task automatic sample_symbol_10b(input int lane_idx, output bit [9:0] raw_10b);
    for (int b = 0; b < 10; b++) begin
      @(rcMonCb);
      if (rcMonCb.RX_P[lane_idx] == 1'b1 && rcMonCb.RX_N[lane_idx] == 1'b0) begin
        raw_10b[b] = 1'b1;
      end else begin
        raw_10b[b] = 1'b0;
      end
    end
  endtask : sample_symbol_10b
 
  //-------------------------------------------------------
  // Task: capture_ts_bytes
  //-------------------------------------------------------
  task automatic capture_ts_bytes(input int lane_idx,
                                  input bit [9:0] sym1_raw_10b,
                                  output ts_ordered_set_bytes_t bytes,
                                  output bit ts_valid);
    bit [9:0] raw_10b;
    bit [7:0] dec_byte;
    bit       is_k;
    bit       code_err;
    bit       disp_valid;
    ts_valid = 1'b1;
    bytes.sym0_com = COM_SYMBOL;
    for (int s = 1; s < TS_OS_LENGTH; s++) begin
      if (s == 1) begin
        raw_10b = sym1_raw_10b;
      end
      else begin
        sample_symbol_10b(lane_idx, raw_10b);
      end
      disp_valid = check_running_disparity(raw_10b, lane_disparity[lane_idx]);
      if (!disp_valid) begin
        `uvm_warning(name, $sformatf("Disparity error on lane %0d at symbol %0d", lane_idx, s))
      end
      dec_byte = decode_8b10b_symbol(raw_10b, is_k, code_err);
      if (code_err) begin
        `uvm_error(name, $sformatf("Code violation on lane %0d at symbol %0d", lane_idx, s))
        ts_valid = 1'b0;
      end
      lane_disparity[lane_idx] = next_running_disparity(raw_10b, lane_disparity[lane_idx]);
      case (s)
        1:  bytes.sym1_link_number   = dec_byte;
        2:  bytes.sym2_lane_number   = dec_byte;
        3:  bytes.sym3_n_fts         = dec_byte;
        4:  bytes.sym4_data_rate_id  = dec_byte;
        5:  bytes.sym5_training_ctrl = dec_byte;
        default: bytes.sym6_15_identifier[s-6] = dec_byte;
      endcase
    end
  endtask : capture_ts_bytes
 
  //-------------------------------------------------------
  // Task: capture_ts
  //-------------------------------------------------------
  task automatic capture_ts(input int lane_idx, input bit [9:0] com_raw_10b, input bit [9:0] sym1_raw_10b);
    ts_ordered_set_bytes_t ts_bytes;
    bit                    ts_valid;
    os_type_e              ts_type;
    if (!check_running_disparity(com_raw_10b, lane_disparity[lane_idx])) begin
      `uvm_warning(name, $sformatf("COM disparity error on lane %0d", lane_idx))
    end
    lane_disparity[lane_idx] = next_running_disparity(com_raw_10b, lane_disparity[lane_idx]);
    capture_ts_bytes(lane_idx, sym1_raw_10b, ts_bytes, ts_valid);
    if (ts_valid) begin
      if (ts_bytes.sym6_15_identifier[0] == TS1_ID_BYTE) begin
        ts_type = OS_TS1;
        ts1_rx_count++;
      end else if (ts_bytes.sym6_15_identifier[0] == TS2_ID_BYTE) begin
        ts_type = OS_TS2;
        ts2_rx_count_complete++;
      end else begin
        ts_type = OS_NONE;
      end
      `uvm_info(name, $sformatf("[Lane %0d] Captured TS: %s | Link: %0d | Lane: %0d",
                lane_idx, ts_type.name(), ts_bytes.sym1_link_number, ts_bytes.sym2_lane_number), UVM_MEDIUM)
    end
  endtask : capture_ts
 
  //-------------------------------------------------------
  // Task: capture_idle
  //-------------------------------------------------------
  task automatic capture_idle(input int lane_idx, input bit [7:0] dec_byte);
    if (dec_byte == IDLE_SYMBOL) begin
      idle_rx_count++;
      `uvm_info(name, $sformatf("[Lane %0d] Captured IDLE Symbol (D0.0)", lane_idx), UVM_HIGH)
    end
  endtask : capture_idle
 
  //-------------------------------------------------------
  // Task: capture_skp
  //-------------------------------------------------------
  task automatic capture_skp(input int lane_idx, input bit [9:0] com_raw_10b, input bit [9:0] skp1_raw_10b);
    bit [9:0] raw_10b;
    bit [7:0] dec_byte;
    bit       is_k;
    bit       code_err;
    bit       disp_valid;
    disp_valid = check_running_disparity(com_raw_10b, lane_disparity[lane_idx]);
    if (!disp_valid) `uvm_warning(name, $sformatf("COM disparity error on lane %0d", lane_idx))
    lane_disparity[lane_idx] = next_running_disparity(com_raw_10b, lane_disparity[lane_idx]);
    disp_valid = check_running_disparity(skp1_raw_10b, lane_disparity[lane_idx]);
    if (!disp_valid) `uvm_warning(name, $sformatf("SKP disparity error on lane %0d at symbol 1", lane_idx))
    lane_disparity[lane_idx] = next_running_disparity(skp1_raw_10b, lane_disparity[lane_idx]);
    for (int i = 0; i < 2; i++) begin
      sample_symbol_10b(lane_idx, raw_10b);
      disp_valid = check_running_disparity(raw_10b, lane_disparity[lane_idx]);
      if (!disp_valid) `uvm_warning(name, $sformatf("SKP disparity error on lane %0d at symbol %0d", lane_idx, i + 2))
      dec_byte = decode_8b10b_symbol(raw_10b, is_k, code_err);
      if (!is_k || dec_byte != SKP_SYMBOL || code_err) begin
        `uvm_warning(name, $sformatf("Unexpected symbol in SKP OS on lane %0d at symbol %0d", lane_idx, i + 2))
      end
      lane_disparity[lane_idx] = next_running_disparity(raw_10b, lane_disparity[lane_idx]);
    end
    skp_rx_count++;
    `uvm_info(name, $sformatf("[Lane %0d] Captured SKP Ordered Set", lane_idx), UVM_MEDIUM)
  endtask : capture_skp
 
  //-------------------------------------------------------
  // Task: monitor_lane
  //-------------------------------------------------------
  task automatic monitor_lane(input int lane_idx);
    bit [9:0] sym0, sym1;
    bit       is_k0, is_k1, err0, err1;
    bit [7:0] dec0, dec1;
    bit       com_found;
    bit       disp_valid;
    sample_symbol_10b(lane_idx, sym0);
    dec0 = decode_8b10b_symbol(sym0, is_k0, err0);
    com_found = (is_k0 && !err0 && dec0 == COM_SYMBOL);
    if (com_found) begin
      sample_symbol_10b(lane_idx, sym1);
      dec1 = decode_8b10b_symbol(sym1, is_k1, err1);
      if (is_k1 && !err1 && dec1 == SKP_SYMBOL) begin
        capture_skp(lane_idx, sym0, sym1);
      end
      else begin
        capture_ts(lane_idx, sym0, sym1);
      end
    end
    else begin
      disp_valid = check_running_disparity(sym0, lane_disparity[lane_idx]);
      if (!disp_valid) begin
        `uvm_warning(name, $sformatf("Disparity error on lane %0d (non-OS symbol)", lane_idx))
      end
      lane_disparity[lane_idx] = next_running_disparity(sym0, lane_disparity[lane_idx]);
      if (err0) begin
        `uvm_warning(name, $sformatf("8b/10b code violation on lane %0d", lane_idx))
      end
      capture_idle(lane_idx, dec0);
    end
  endtask : monitor_lane
 
  //=======================================================================
  // check_electrical_idle_exit_any_lane
  //=======================================================================
  function automatic bit check_electrical_idle_exit_any_lane();
    for (int lane = 0; lane < rc_agent_cfg_h.active_lanes; lane++) begin
      if ((rcMonCb.RX_P[lane] == 1'b1 && rcMonCb.RX_N[lane] == 1'b0) ||
          (rcMonCb.RX_P[lane] == 1'b0 && rcMonCb.RX_N[lane] == 1'b1)) begin
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction : check_electrical_idle_exit_any_lane
 
  //=======================================================================
  // sample_rx_detect_status
  //=======================================================================
  function automatic bit [PCIE_MAX_LANES-1:0] sample_rx_detect_status();
    bit [PCIE_MAX_LANES-1:0] detected_mask;
    detected_mask = '0;
    for (int lane = 0; lane < rc_agent_cfg_h.active_lanes; lane++) begin
      if ((rcMonCb.RX_P[lane] == 1'b1 && rcMonCb.RX_N[lane] == 1'b0) ||
          (rcMonCb.RX_P[lane] == 1'b0 && rcMonCb.RX_N[lane] == 1'b1)) begin
        detected_mask[lane] = 1'b1;
      end
    end
    return detected_mask;
  endfunction : sample_rx_detect_status
 
  //-------------------------------------------------------
  // Task: monitor_detect_quiet
  //-------------------------------------------------------
  task automatic monitor_detect_quiet(output detect_substate_e next_substate);
    `uvm_info(name, "Monitoring Detect.Quiet State", UVM_MEDIUM)
    repeat (rc_agent_cfg_h.detect_timeout_cycles) begin
      @(rcMonCb);
      if (check_electrical_idle_exit_any_lane()) begin
        `uvm_info(name, "Monitor: Electrical Idle Exit detected -> Moving to Detect.Active", UVM_HIGH)
        next_substate = DETECT_ACTIVE;
        return;
      end
    end
    `uvm_info(name, "Monitor: Detect.Quiet timeout expired -> Moving to Detect.Active", UVM_HIGH)
    next_substate = DETECT_ACTIVE;
  endtask : monitor_detect_quiet
 
  //-------------------------------------------------------
  // Task: monitor_detect_active
  //-------------------------------------------------------
  task automatic monitor_detect_active(output ltssm_state_e next_state);
    bit [PCIE_MAX_LANES-1:0] detected_mask;
    bit [PCIE_MAX_LANES-1:0] expected_mask;
    `uvm_info(name, "Monitoring Detect.Active State", UVM_MEDIUM)
    expected_mask = '0;
    for (int lane = 0; lane < rc_agent_cfg_h.active_lanes; lane++) begin
      expected_mask[lane] = 1'b1;
    end
    detected_mask = sample_rx_detect_status();
    if (detected_mask == expected_mask) begin
      `uvm_info(name, "Monitor: Receiver detected on all lanes -> Transitioning to POLLING", UVM_HIGH)
      next_state = POLLING_ST;
      return;
    end
    else if (detected_mask == '0) begin
      `uvm_info(name, "Monitor: No receiver detected -> Returning to DETECT", UVM_HIGH)
      next_state = DETECT_ST;
      return;
    end
    `uvm_info(name, "Monitor: Partial receiver detection observed -> Monitoring retry window", UVM_HIGH)
    repeat (rc_agent_cfg_h.detect_timeout_cycles) begin
      @(rcMonCb);
    end
    detected_mask = sample_rx_detect_status();
    if (detected_mask == expected_mask) begin
      `uvm_info(name, "Monitor: Receiver detected on retry -> Transitioning to POLLING", UVM_HIGH)
      next_state = POLLING_ST;
    end else begin
      `uvm_info(name, "Monitor: Receiver detection failed on retry -> Returning to DETECT", UVM_HIGH)
      next_state = DETECT_ST;
    end
  endtask : monitor_detect_active
 
  //-------------------------------------------------------
  // Task: monitor_polling_active
  // Watches for TS1 ordered sets and exits once CONSEC_TS_COUNT
  // consecutive valid TS1s are observed - mirrors the RX-side
  // exit condition used by run_polling_active() in the driver BFM.
  //-------------------------------------------------------
  task automatic monitor_polling_active(output polling_substate_e next_substate,
                                         output ltssm_state_e      next_state);
 
    bit [9:0] sym0, sym1;
    bit       is_k0, err0;
    bit [7:0] dec0;
 
    ts_ordered_set_bytes_t ts_bytes;
    bit                    ts_valid;
    int unsigned           consec_match_cnt;
    int                    lane_idx;
    time                   start_time;
 
    `uvm_info(name, "Entering Polling.Active Monitor", UVM_MEDIUM)
 
    lane_idx         = 0;   // representative lane; all active lanes carry the same TS1 content
    ts1_rx_count     = 0;
    consec_match_cnt = 0;
    start_time       = $time;
 
    forever begin
 
      sample_symbol_10b(lane_idx, sym0);
      dec0 = decode_8b10b_symbol(sym0, is_k0, err0);
 
      if (is_k0 && !err0 && dec0 == COM_SYMBOL) begin
 
        sample_symbol_10b(lane_idx, sym1);
        capture_ts_bytes(lane_idx, sym1, ts_bytes, ts_valid);
 
        if (ts_valid && ts_bytes.sym6_15_identifier[0] == TS1_ID_BYTE) begin
          ts1_rx_count++;
          consec_match_cnt++;
          `uvm_info(
            name,
            $sformatf(
              "Polling.Active: TS1 received (consecutive = %0d/%0d), Link = %0d, Lane = %0d",
              consec_match_cnt, CONSEC_TS_COUNT,
              ts_bytes.sym1_link_number, ts_bytes.sym2_lane_number
            ),
            UVM_HIGH
          );
        end
        else begin
          consec_match_cnt = 0;
        end
 
      end
      else begin
        consec_match_cnt = 0;
      end
 
      // Success: enough consecutive matching TS1 observed
      if (consec_match_cnt >= CONSEC_TS_COUNT) begin
        `uvm_info(name, "Polling.Active Monitor: consecutive TS1 threshold met -> Polling.Configuration", UVM_LOW)
        next_substate = POLLING_CONFIG;
        next_state    = POLLING_ST;
        return;
      end
 
      // Safety-net timeout
      if (($time - start_time) >= (POLLING_TIMEOUT_MS * 1ms)) begin
        `uvm_error(name, "Polling.Active Monitor Timeout")
        next_state = DETECT_ST;
        return;
      end
 
    end
 
  endtask : monitor_polling_active
 
  //-------------------------------------------------------
  // Task: monitor_polling_configuration
  // Watches for TS2 ordered sets and exits once CONSEC_TS2_COMPLETE
  // consecutive valid TS2s are observed - mirrors the RX-side
  // exit condition used by run_polling_configuration() in the driver BFM.
  //-------------------------------------------------------
  task automatic monitor_polling_configuration(output ltssm_state_e next_state);
 
    bit [9:0] sym0, sym1;
    bit       is_k0, err0;
    bit [7:0] dec0;
 
    ts_ordered_set_bytes_t ts_bytes;
    bit                    ts_valid;
    int unsigned           consec_match_cnt;
    int                    lane_idx;
    time                   start_time;
 
    `uvm_info(name, "Entering Polling.Configuration Monitor", UVM_MEDIUM)
 
    lane_idx              = 0;
    ts2_rx_count_complete = 0;
    consec_match_cnt      = 0;
    start_time            = $time;
 
    forever begin
 
      sample_symbol_10b(lane_idx, sym0);
      dec0 = decode_8b10b_symbol(sym0, is_k0, err0);
 
      if (is_k0 && !err0 && dec0 == COM_SYMBOL) begin
 
        sample_symbol_10b(lane_idx, sym1);
        capture_ts_bytes(lane_idx, sym1, ts_bytes, ts_valid);
 
        if (ts_valid && ts_bytes.sym6_15_identifier[0] == TS2_ID_BYTE) begin
          ts2_rx_count_complete++;
          consec_match_cnt++;
          `uvm_info(
            name,
            $sformatf(
              "Polling.Configuration: TS2 received (consecutive = %0d/%0d), Link = %0d, Lane = %0d",
              consec_match_cnt, CONSEC_TS2_COMPLETE,
              ts_bytes.sym1_link_number, ts_bytes.sym2_lane_number
            ),
            UVM_HIGH
          );
        end
        else begin
          consec_match_cnt = 0;
        end
 
      end
      else begin
        consec_match_cnt = 0;
      end
 
      // Success: enough consecutive matching TS2 observed
      if (consec_match_cnt >= CONSEC_TS2_COMPLETE) begin
        `uvm_info(name, "Polling.Configuration Monitor: consecutive TS2 threshold met -> Configuration", UVM_LOW)
        next_state = CONFIG_ST;
        return;
      end
 
      // Safety-net timeout
      if (($time - start_time) >= (CONFIG_TIMEOUT_MS * 1ms)) begin
        `uvm_error(name, "Polling.Configuration Monitor Timeout")
        next_state = DETECT_ST;
        return;
      end
 
    end
  endtask : monitor_polling_configuration
 
//-------------------------------------------------------
// Task: monitor_receive_ts
//-------------------------------------------------------
task automatic monitor_receive_ts(output ts_ordered_set_bytes_t bytes,
                                   output bit [7:0]              rx_lane_number [0:PCIE_MAX_LANES-1],
                                   output bit                    valid);
  bit [7:0] sym_array  [0:TS_OS_LENGTH-1];
  bit       is_k_array [0:TS_OS_LENGTH-1];
  bit [7:0] dec_byte;
  bit       is_k;
  bit       code_err;
 
  valid = 1'b1;
 
  for (int s = 0; s < TS_OS_LENGTH; s++) begin
    for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
      bit [9:0] raw_10b;
      sample_symbol_10b(l, raw_10b);
      dec_byte = decode_8b10b_symbol(raw_10b, is_k, code_err);
      if (code_err) valid = 1'b0;
      lane_disparity[l] = next_running_disparity(raw_10b, lane_disparity[l]);
 
      if (s == 2) begin
        rx_lane_number[l] = dec_byte;
      end
      else if (l == 0) begin
        sym_array[s]  = dec_byte;
        is_k_array[s] = is_k;
      end
    end
  end
 
  bytes.sym0_com           = sym_array[0];
  bytes.sym1_link_number   = sym_array[1];
  bytes.sym2_lane_number   = rx_lane_number[0];
  bytes.sym3_n_fts         = sym_array[3];
  bytes.sym4_data_rate_id  = sym_array[4];
  bytes.sym5_training_ctrl = sym_array[5];
  for (int i = 0; i < 10; i++) bytes.sym6_15_identifier[i] = sym_array[6+i];
 
  if (sym_array[0] != COM_SYMBOL || !is_k_array[0]) valid = 1'b0;
 
endtask : monitor_receive_ts
 
 
//-------------------------------------------------------
// Function: detect_lane_reversal
// Duplicated from driver BFM - interfaces can't call each
// other's functions directly. Checks if EP's received lane
// numbers come back in mirrored order vs what RC expects.
//-------------------------------------------------------
function automatic bit detect_lane_reversal(input bit [7:0] ep_lane [0:PCIE_MAX_LANES-1]);
  for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
    if (ep_lane[l] !== (rc_agent_cfg_h.active_lanes - 1 - l))
      return 1'b0;
  return 1'b1;
endfunction : detect_lane_reversal
 
 
//-------------------------------------------------------
// Task: monitor_configuration_linkwidth_start
//-------------------------------------------------------
task automatic monitor_configuration_linkwidth_start(output config_substate_e next_config_substate,
                                                       output ltssm_state_e    next_state);
  ts_ordered_set_bytes_t rx_bytes;
  bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
  bit                     rx_valid;
  int unsigned            consec_link_match_cnt;
  int unsigned            ts_attempt_cnt;
 
  `uvm_info(name, "Monitoring Configuration.Linkwidth.Start", UVM_MEDIUM)
 
  consec_link_match_cnt  = 0;
  ts_attempt_cnt          = 0;
  configured_link_number  = rc_agent_cfg_h.link_number;
 
  forever begin
    monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
    ts_attempt_cnt++;
 
    if (rx_valid &&
        rx_bytes.sym1_link_number == configured_link_number &&
        rx_lane_number[0] == PAD_SYMBOL) begin
      consec_link_match_cnt++;
      `uvm_info(name, $sformatf("Configuration.Linkwidth.Start: matching TS1 (%0d/%0d)",
                                 consec_link_match_cnt, CONSEC_TS_REQUIRED), UVM_HIGH)
    end
    else begin
      consec_link_match_cnt = 0;
    end
 
    if (consec_link_match_cnt >= CONSEC_TS_REQUIRED) begin
      `uvm_info(name, "Configuration.Linkwidth.Start Monitor completed", UVM_LOW)
      next_config_substate = CFG_LINKWIDTH_ACCEPT;
      next_state             = CONFIG_ST;
      return;
    end
 
    if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
      `uvm_error(name, "Configuration.Linkwidth.Start Monitor Timeout")
      next_state = DETECT_ST;
      return;
    end
  end
endtask : monitor_configuration_linkwidth_start
 
 
//-------------------------------------------------------
// Task: monitor_configuration_linkwidth_accept
//-------------------------------------------------------
task automatic monitor_configuration_linkwidth_accept(output config_substate_e next_config_substate,
                                                        output ltssm_state_e    next_state);
  ts_ordered_set_bytes_t rx_bytes;
  bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
  bit                     rx_valid;
  int unsigned            ts_attempt_cnt;
  bit                     use_reversal;
  bit                     valid_group;
 
  `uvm_info(name, "Monitoring Configuration.Linkwidth.Accept", UVM_MEDIUM)
 
  ts_attempt_cnt = 0;
 
  forever begin
    monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
    ts_attempt_cnt++;
 
    if (rx_valid) begin
      use_reversal = detect_lane_reversal(rx_lane_number);
 
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
        configured_lane_number[l] = use_reversal ?
            rx_lane_number[rc_agent_cfg_h.active_lanes-1-l] : rx_lane_number[l];
      end
 
      valid_group = 1'b1;
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        if (configured_lane_number[l] == PAD_SYMBOL) valid_group = 1'b0;
 
      if (valid_group) begin
        `uvm_info(name, $sformatf("Configuration.Linkwidth.Accept Monitor completed (reversal=%0b)", use_reversal), UVM_LOW)
        next_config_substate = CFG_LANENUM_WAIT;
        next_state             = CONFIG_ST;
        return;
      end
    end
 
    if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
      `uvm_error(name, "Configuration.Linkwidth.Accept Monitor Timeout")
      next_state = DETECT_ST;
      return;
    end
  end
endtask : monitor_configuration_linkwidth_accept
 
 
//-------------------------------------------------------
// Task: monitor_configuration_lanenum_wait
//-------------------------------------------------------
task automatic monitor_configuration_lanenum_wait(output config_substate_e next_config_substate,
                                                     output ltssm_state_e    next_state);
  ts_ordered_set_bytes_t rx_bytes;
  bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
  bit                     rx_valid;
  int unsigned            consec_match_cnt;
  int unsigned            ts_attempt_cnt;
  bit                     valid_lane_group;
 
  `uvm_info(name, "Monitoring Configuration.Lanenum.Wait", UVM_MEDIUM)
 
  consec_match_cnt = 0;
  ts_attempt_cnt   = 0;
 
  forever begin
    monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
    ts_attempt_cnt++;
 
    if (rx_valid) begin
      valid_lane_group = 1'b1;
      if (rx_bytes.sym1_link_number != configured_link_number) valid_lane_group = 1'b0;
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        if (rx_lane_number[l] != configured_lane_number[l]) valid_lane_group = 1'b0;
 
      consec_match_cnt = valid_lane_group ? consec_match_cnt + 1 : 0;
 
      if (consec_match_cnt >= CONSEC_TS_REQUIRED) begin
        `uvm_info(name, "Configuration.Lanenum.Wait Monitor completed", UVM_LOW)
        next_config_substate = CFG_COMPLETE;
        next_state             = CONFIG_ST;
        return;
      end
    end
 
    if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
      `uvm_error(name, "Configuration.Lanenum.Wait Monitor Timeout")
      next_state = DETECT_ST;
      return;
    end
  end
endtask : monitor_configuration_lanenum_wait
 
 
//-------------------------------------------------------
// Task: monitor_configuration_lanenum_accept
//-------------------------------------------------------
task automatic monitor_configuration_lanenum_accept(output config_substate_e next_config_substate,
                                                       output ltssm_state_e    next_state);
  ts_ordered_set_bytes_t rx_bytes;
  bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
  bit                     rx_valid;
  int unsigned            consec_match_cnt;
  int unsigned            ts_attempt_cnt;
  bit                     valid_group;
  bit                     smaller_link_detected;
  bit                     any_non_pad;
 
  `uvm_info(name, "Monitoring Configuration.Lanenum.Accept", UVM_MEDIUM)
 
  consec_match_cnt      = 0;
  ts_attempt_cnt         = 0;
 
  forever begin
    monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
    ts_attempt_cnt++;
 
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
        `uvm_info(name, "Configuration.Lanenum.Accept Monitor completed", UVM_LOW)
        next_config_substate = CFG_COMPLETE;
        next_state             = CONFIG_ST;
        return;
      end
 
      if (smaller_link_detected) begin
        `uvm_info(name, "Monitor: Reduced Link Width observed", UVM_LOW)
        for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
          configured_lane_number[l] = rx_lane_number[l];
        next_config_substate = CFG_LANENUM_WAIT;
        next_state             = CONFIG_ST;
        return;
      end
 
      any_non_pad = 1'b0;
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        if (rx_lane_number[l] != PAD_SYMBOL) any_non_pad = 1'b1;
 
      if (!any_non_pad) begin
        `uvm_warning(name, "Monitor: All received Lane Numbers are PAD")
        next_state = DETECT_ST;
        return;
      end
    end
 
    if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
      `uvm_error(name, "Configuration.Lanenum.Accept Monitor Timeout")
      next_state = DETECT_ST;
      return;
    end
  end
endtask : monitor_configuration_lanenum_accept
 
 
//-------------------------------------------------------
// Task: monitor_configuration_complete
//-------------------------------------------------------
task automatic monitor_configuration_complete(output config_substate_e next_config_substate,
                                                output ltssm_state_e    next_state);
  ts_ordered_set_bytes_t rx_bytes;
  bit [7:0]               rx_lane_number [0:PCIE_MAX_LANES-1];
  bit                     rx_valid;
  int unsigned            consec_ts2_cnt;
  int unsigned            ts_attempt_cnt;
  bit                     valid_group;
 
  `uvm_info(name, "Monitoring Configuration.Complete", UVM_MEDIUM)
 
  consec_ts2_cnt = 0;
  ts_attempt_cnt = 0;
 
  forever begin
    monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
    ts_attempt_cnt++;
 
    if (rx_valid) begin
      valid_group = 1'b1;
      if (rx_bytes.sym1_link_number != configured_link_number) valid_group = 1'b0;
      for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++)
        if (rx_lane_number[l] != configured_lane_number[l]) valid_group = 1'b0;
      if (rx_bytes.sym6_15_identifier[0] != TS2_ID_BYTE) valid_group = 1'b0;
 
      consec_ts2_cnt = valid_group ? consec_ts2_cnt + 1 : 0;
 
      if (consec_ts2_cnt >= CONSEC_TS_REQUIRED) begin
        `uvm_info(name, "Configuration.Complete Monitor finished", UVM_LOW)
        next_config_substate = CFG_IDLE;
        next_state             = CONFIG_ST;
        return;
      end
    end
 
    if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
      `uvm_error(name, "Configuration.Complete Monitor Timeout")
      next_state = DETECT_ST;
      return;
    end
  end
endtask : monitor_configuration_complete
 
 
//-------------------------------------------------------
// Task: monitor_configuration_idle
//-------------------------------------------------------
task automatic monitor_configuration_idle(output ltssm_state_e next_state);
  bit [7:0]    rx_byte [0:PCIE_MAX_LANES-1];
  bit          all_lanes_idle;
  int unsigned consec_idle_cnt;
  int unsigned idle_attempt_cnt;
  bit [9:0]    raw_10b;
  bit          is_k;
  bit          code_err;
 
  `uvm_info(name, "Monitoring Configuration.Idle", UVM_MEDIUM)
 
  consec_idle_cnt   = 0;
  idle_attempt_cnt  = 0;
 
  forever begin
    all_lanes_idle = 1'b1;
    for (int l = 0; l < rc_agent_cfg_h.active_lanes; l++) begin
      sample_symbol_10b(l, raw_10b);
      rx_byte[l] = decode_8b10b_symbol(raw_10b, is_k, code_err);
      lane_disparity[l] = next_running_disparity(raw_10b, lane_disparity[l]);
      if (code_err || rx_byte[l] != IDLE_SYMBOL) all_lanes_idle = 1'b0;
    end
    idle_attempt_cnt++;
 
    consec_idle_cnt = all_lanes_idle ? consec_idle_cnt + 1 : 0;
 
    if (consec_idle_cnt >= MIN_IDLE_RX) begin
      `uvm_info(name, "Configuration.Idle Monitor completed - Link Up (L0)", UVM_LOW)
      next_state = L0_ST;
      return;
    end
 
    if (idle_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
      `uvm_error(name, "Configuration.Idle Monitor Timeout")
      next_state = DETECT_ST;
      return;
    end
  end
endtask : monitor_configuration_idle
 
 
endinterface : pcie_phy_rc_monitor_bfm
`endif
