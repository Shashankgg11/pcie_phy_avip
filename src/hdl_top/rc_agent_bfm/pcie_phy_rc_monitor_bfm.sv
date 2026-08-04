`ifndef PCIE_PHY_RC_MONITOR_BFM_INCLUDED_
`define PCIE_PHY_RC_MONITOR_BFM_INCLUDED_
//-------------------------------------------------------
// Importing global package
//-------------------------------------------------------
import pcie_phy_pkg::*;
interface pcie_phy_rc_monitor_bfm(input logic pclk,
                                   input logic preset_n,
                                   input logic [PCIE_MAX_LANES-1:0] TX_P,
                                   input logic [PCIE_MAX_LANES-1:0] TX_N
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
    input TX_P, TX_N;
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
  // Wait for reset before monitoring starts.
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
  // Reset all monitor variables to their default values.
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
      if (rcMonCb.TX_P[lane_idx] == 1'b1 && rcMonCb.TX_N[lane_idx] == 1'b0) begin
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
 
    for (int lane = 0;
         lane < rc_agent_cfg_h.active_lanes;
         lane++) begin
 
      if ((rcMonCb.TX_P[lane] == 1'b1 &&
           rcMonCb.TX_N[lane] == 1'b0) ||
          (rcMonCb.TX_P[lane] == 1'b0 &&
           rcMonCb.TX_N[lane] == 1'b1)) begin
 
        return 1'b1;
 
      end
 
    end
 
    return 1'b0;
 
  endfunction : check_electrical_idle_exit_any_lane
 
 
  //=======================================================================
  // sample_rx_detect_status
  //=======================================================================
  function automatic bit [PCIE_MAX_LANES-1:0]
    sample_rx_detect_status();
 
    bit [PCIE_MAX_LANES-1:0] detected_mask;
 
    detected_mask = '0;
 
    for (int lane = 0;
         lane < rc_agent_cfg_h.active_lanes;
         lane++) begin
 
      if ((rcMonCb.TX_P[lane] == 1'b1 &&
           rcMonCb.TX_N[lane] == 1'b0) ||
          (rcMonCb.TX_P[lane] == 1'b0 &&
           rcMonCb.TX_N[lane] == 1'b1)) begin
 
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
endinterface : pcie_phy_rc_monitor_bfm
`endif
