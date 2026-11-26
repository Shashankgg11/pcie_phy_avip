//working code RC mon_bfm till l0 

`ifndef PCIE_PHY_RC_MONITOR_BFM_INCLUDED_
`define PCIE_PHY_RC_MONITOR_BFM_INCLUDED_

import pcie_phy_pkg::*;

interface pcie_phy_rc_monitor_bfm
(
    input logic pclk,
    input logic preset_n,
    input logic [PCIE_MAX_LANES-1:0] RX_P,
    input logic [PCIE_MAX_LANES-1:0] RX_N
);

    import uvm_pkg::*;
    import pcie_phy_pkg::*;
    import pcie_phy_rc_pkg::*;

    string name = "PCIE_PHY_RC_MONITOR_BFM";

    pcie_phy_rc_agent_config rc_agent_cfg_h;

    clocking rcMonCb @(posedge pclk);
        default input #1step;
        input RX_P;
        input RX_N;
        input preset_n;
    endclocking

    pcie_gen_e current_speed;
    bit [7:0] configured_link_number;
    bit [7:0] configured_lane_number [0:PCIE_MAX_LANES-1];
    int unsigned ts1_rx_count;
    int unsigned ts2_rx_count_complete;
    int unsigned idle_rx_count;
    int unsigned skp_rx_count;
    running_disparity_e lane_disparity [0:PCIE_MAX_LANES-1];

    bit symbol_lock_acquired;
    int unsigned consec_invalid_rx_count;


  // ---------------- Recovery tracking (added) ----------------
  bit                  directed_speed_change;
  pcie_gen_e           current_rate;
  bit                  changed_speed_recovery;
  bit                  successful_speed_negotiation;
  bit                  equalization_done_this_speed;
  bit [7:0]            negotiated_tx_preset;
  recovery_substate_e  current_recovery_substate;
  bit [7:0]            mod_win     [0:15];
  bit                  mod_win_err [0:15];

    localparam int unsigned MAX_CONSEC_INVALID_RX = 3;
    localparam int unsigned MAX_LOCK_SEARCH_EDGES = 2000;

    initial begin
        `uvm_info(name, "PCIE PHY RC MONITOR BFM STARTED", UVM_LOW)
    end

    task wait_for_reset();
        @(negedge preset_n);
        `uvm_info(name, "SYSTEM RESET DETECTED IN MONITOR", UVM_HIGH)
        default_values();
        @(posedge preset_n);
        `uvm_info(name, "SYSTEM RESET DEACTIVATED IN MONITOR", UVM_HIGH)
    endtask : wait_for_reset

    task default_values();
        configured_link_number = PAD_SYMBOL;
        foreach (configured_lane_number[l]) configured_lane_number[l] = PAD_SYMBOL;
        foreach (lane_disparity[l]) begin
            if (rc_agent_cfg_h != null)
                lane_disparity[l] = rc_agent_cfg_h.initial_disparity;
            else
                lane_disparity[l] = RD_MINUS;
        end
        current_speed = GEN1;
        ts1_rx_count = 0;
        ts2_rx_count_complete = 0;
        idle_rx_count = 0;
        skp_rx_count = 0;
        symbol_lock_acquired = 1'b0;
        consec_invalid_rx_count = 0;
    directed_speed_change        = 1'b0;
    current_rate                 = GEN1;
    changed_speed_recovery       = 1'b0;
    successful_speed_negotiation = 1'b0;
    equalization_done_this_speed = 1'b0;
    negotiated_tx_preset         = 8'h00;
    current_recovery_substate    = RECOVERY_RCVR_LOCK;
    endtask : default_values

    function automatic int get_active_lanes();
        if (rc_agent_cfg_h == null) return 1;
        return rc_agent_cfg_h.active_lanes;
    endfunction : get_active_lanes

    function automatic bit [7:0] decode_8b10b_symbol
    (
        input  bit [9:0] raw_10b,
        output bit       is_k_code,
        output bit       code_err,
        output running_disparity_e matched_rd
    );
        bit found;
        is_k_code = 1'b0;
        code_err = 1'b0;
        matched_rd = RD_MINUS;

        case (raw_10b)
            K_COM_N: begin decode_8b10b_symbol = COM_SYMBOL; is_k_code = 1'b1; matched_rd = RD_MINUS; end
            K_COM_P: begin decode_8b10b_symbol = COM_SYMBOL; is_k_code = 1'b1; matched_rd = RD_PLUS;  end
            K_PAD_N: begin decode_8b10b_symbol = PAD_SYMBOL; is_k_code = 1'b1; matched_rd = RD_MINUS; end
            K_PAD_P: begin decode_8b10b_symbol = PAD_SYMBOL; is_k_code = 1'b1; matched_rd = RD_PLUS;  end
            K_SKP_N: begin decode_8b10b_symbol = SKP_SYMBOL; is_k_code = 1'b1; matched_rd = RD_MINUS; end
            K_SKP_P: begin decode_8b10b_symbol = SKP_SYMBOL; is_k_code = 1'b1; matched_rd = RD_PLUS;  end
            K_STP_N: begin decode_8b10b_symbol = STP_TOKEN;  is_k_code = 1'b1; matched_rd = RD_MINUS; end
            K_STP_P: begin decode_8b10b_symbol = STP_TOKEN;  is_k_code = 1'b1; matched_rd = RD_PLUS;  end
            K_SDP_N: begin decode_8b10b_symbol = SDP_TOKEN;  is_k_code = 1'b1; matched_rd = RD_MINUS; end
            K_SDP_P: begin decode_8b10b_symbol = SDP_TOKEN;  is_k_code = 1'b1; matched_rd = RD_PLUS;  end
            K_END_N: begin decode_8b10b_symbol = END_TOKEN;  is_k_code = 1'b1; matched_rd = RD_MINUS; end
            K_END_P: begin decode_8b10b_symbol = END_TOKEN;  is_k_code = 1'b1; matched_rd = RD_PLUS;  end
            K_EDB_N: begin decode_8b10b_symbol = EDB_TOKEN;  is_k_code = 1'b1; matched_rd = RD_MINUS; end
            K_EDB_P: begin decode_8b10b_symbol = EDB_TOKEN;  is_k_code = 1'b1; matched_rd = RD_PLUS;  end
            K_EIE_N: begin decode_8b10b_symbol = EIE_SYM;    is_k_code = 1'b1; matched_rd = RD_MINUS; end
            K_EIE_P: begin decode_8b10b_symbol = EIE_SYM;    is_k_code = 1'b1; matched_rd = RD_PLUS;  end
            default: begin
                found = 1'b0;
                decode_8b10b_symbol = 8'hXX;
                for (int i = 0; i < 256; i++) begin
                    if (D_NEG_DISP[i] == raw_10b) begin
                        decode_8b10b_symbol = i[7:0];
                        matched_rd = RD_MINUS;
                        found = 1'b1;
                    end
                    else if (D_POS_DISP[i] == raw_10b) begin
                        decode_8b10b_symbol = i[7:0];
                        matched_rd = RD_PLUS;
                        found = 1'b1;
                    end
                end
                if (!found) code_err = 1'b1;
            end
        endcase
    endfunction : decode_8b10b_symbol

    task automatic sample_symbol_10b
    (
        input  int lane_idx,
        output bit [9:0] raw_10b
    );
        raw_10b = '0;
        for (int b = 0; b < 10; b++) begin
            @(rcMonCb);
            raw_10b[b] = rcMonCb.RX_P[lane_idx];
        end
    endtask : sample_symbol_10b

    task automatic sample_all_lanes_symbol_10b
    (
        output bit [9:0] raw_10b [0:PCIE_MAX_LANES-1]
    );
        foreach (raw_10b[l]) raw_10b[l] = '0;
        for (int b = 0; b < 10; b++) begin
            @(rcMonCb);
            for (int l = 0; l < get_active_lanes(); l++) begin
                raw_10b[l][b] = rcMonCb.RX_P[l];
            end
        end
    endtask : sample_all_lanes_symbol_10b

    task automatic acquire_symbol_lock
    (
        output bit [9:0] locked_code [0:PCIE_MAX_LANES-1],
        output bit found
    );
        bit [9:0] window [0:PCIE_MAX_LANES-1];
        bit all_valid;
        bit [7:0] tmp_dec [0:PCIE_MAX_LANES-1];
        bit tmp_is_k [0:PCIE_MAX_LANES-1];
        bit tmp_err [0:PCIE_MAX_LANES-1];
        running_disparity_e tmp_rd [0:PCIE_MAX_LANES-1];
        int unsigned edges_searched;

        found = 1'b0;
        edges_searched = 0;
        foreach (window[l]) window[l] = '0;
        foreach (locked_code[l]) locked_code[l] = '0;

        while (edges_searched < MAX_LOCK_SEARCH_EDGES) begin
            @(rcMonCb);
            edges_searched++;
            for (int l = 0; l < get_active_lanes(); l++)
                window[l] = {rcMonCb.RX_P[l], window[l][9:1]};

            if ((window[0] == K_COM_N) || (window[0] == K_COM_P)) begin
                all_valid = 1'b1;
                for (int l = 0; l < get_active_lanes(); l++) begin
                    locked_code[l] = window[l];
                    tmp_dec[l] = decode_8b10b_symbol(window[l], tmp_is_k[l], tmp_err[l], tmp_rd[l]);
                    if (tmp_err[l]) all_valid = 1'b0;
                    if (!tmp_is_k[l]) all_valid = 1'b0;
                    if (tmp_dec[l] != COM_SYMBOL) all_valid = 1'b0;
                end
                if (all_valid) begin
                    for (int l = 0; l < get_active_lanes(); l++) lane_disparity[l] = tmp_rd[l];
                    symbol_lock_acquired = 1'b1;
                    found = 1'b1;
                    `uvm_info(name, $sformatf("Symbol lock acquired after %0d edges", edges_searched), UVM_MEDIUM)
                    return;
                end
            end
        end
        `uvm_warning(name, $sformatf("No valid COM found within %0d edges", MAX_LOCK_SEARCH_EDGES))
    endtask : acquire_symbol_lock

    task automatic acquire_idle_symbol_lock
    (
        output bit [9:0] locked_code [0:PCIE_MAX_LANES-1],
        output bit found
    );
        bit [9:0] window [0:PCIE_MAX_LANES-1];
        bit all_valid;
        bit [7:0] tmp_dec [0:PCIE_MAX_LANES-1];
        bit tmp_is_k [0:PCIE_MAX_LANES-1];
        bit tmp_err [0:PCIE_MAX_LANES-1];
        running_disparity_e tmp_rd [0:PCIE_MAX_LANES-1];
        int unsigned edges_searched;

        found = 1'b0;
        edges_searched = 0;
        foreach (window[l]) window[l] = '0;
        foreach (locked_code[l]) locked_code[l] = '0;

        while (edges_searched < MAX_LOCK_SEARCH_EDGES) begin
            @(rcMonCb);
            edges_searched++;
            for (int l = 0; l < get_active_lanes(); l++)
                window[l] = {rcMonCb.RX_P[l], window[l][9:1]};

            if ((window[0] == D_NEG_DISP[IDLE_SYMBOL]) || (window[0] == D_POS_DISP[IDLE_SYMBOL])) begin
                all_valid = 1'b1;
                for (int l = 0; l < get_active_lanes(); l++) begin
                    locked_code[l] = window[l];
                    tmp_dec[l] = decode_8b10b_symbol(window[l], tmp_is_k[l], tmp_err[l], tmp_rd[l]);
                    if (tmp_err[l]) all_valid = 1'b0;
                    if (tmp_is_k[l]) all_valid = 1'b0;
                    if (tmp_dec[l] != IDLE_SYMBOL) all_valid = 1'b0;
                end
                if (all_valid) begin
                    for (int l = 0; l < get_active_lanes(); l++) lane_disparity[l] = tmp_rd[l];
                    symbol_lock_acquired = 1'b1;
                    found = 1'b1;
                    `uvm_info(name, $sformatf("Idle symbol lock acquired after %0d edges", edges_searched), UVM_MEDIUM)
                    return;
                end
            end
        end
        `uvm_warning(name, $sformatf("No valid IDLE found within %0d edges", MAX_LOCK_SEARCH_EDGES))
    endtask : acquire_idle_symbol_lock

    task automatic capture_ts_bytes
    (
        input int lane_idx,
        input bit [9:0] sym1_raw_10b,
        output ts_ordered_set_bytes_t bytes,
        output bit ts_valid
    );
        bit [9:0] raw_10b;
        bit [7:0] dec_byte;
        bit is_k;
        bit code_err;
        running_disparity_e matched_rd;

        ts_valid = 1'b1;
        bytes = '0;
        bytes.sym0_com = COM_SYMBOL;

        for (int s = 1; s < TS_OS_LENGTH; s++) begin
            if (s == 1) raw_10b = sym1_raw_10b;
            else sample_symbol_10b(lane_idx, raw_10b);

            dec_byte = decode_8b10b_symbol(raw_10b, is_k, code_err, matched_rd);

            if (code_err) begin
                ts_valid = 1'b0;
                `uvm_warning(name, $sformatf("Code violation lane=%0d TS symbol=%0d", lane_idx, s))
            end
            else begin
                lane_disparity[lane_idx] = matched_rd;
            end

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

    task automatic capture_ts
    (
        input int lane_idx,
        input bit [9:0] com_raw_10b,
        input bit [9:0] sym1_raw_10b
    );
        ts_ordered_set_bytes_t ts_bytes;
        bit ts_valid;
        bit is_k;
        bit code_err;
        running_disparity_e matched_rd;

        decode_8b10b_symbol(com_raw_10b, is_k, code_err, matched_rd);
        if (!code_err) lane_disparity[lane_idx] = matched_rd;

        capture_ts_bytes(lane_idx, sym1_raw_10b, ts_bytes, ts_valid);

        if (ts_valid) begin
            if (ts_bytes.sym6_15_identifier[0] == TS1_ID_BYTE) begin
                ts1_rx_count++;
                `uvm_info(name, $sformatf("Lane %0d: TS1 Link=%0d Lane=%0d", lane_idx, ts_bytes.sym1_link_number, ts_bytes.sym2_lane_number), UVM_HIGH)
            end
            else if (ts_bytes.sym6_15_identifier[0] == TS2_ID_BYTE) begin
                ts2_rx_count_complete++;
                `uvm_info(name, $sformatf("Lane %0d: TS2 Link=%0d Lane=%0d", lane_idx, ts_bytes.sym1_link_number, ts_bytes.sym2_lane_number), UVM_HIGH)
            end
        end
    endtask : capture_ts

    task automatic capture_idle
    (
        input int lane_idx,
        input bit [7:0] dec_byte
    );
        if (dec_byte == IDLE_SYMBOL) begin
            idle_rx_count++;
            `uvm_info(name, $sformatf("Lane %0d: IDLE", lane_idx), UVM_HIGH)
        end
    endtask : capture_idle

    task automatic capture_skp
    (
        input int lane_idx,
        input bit [9:0] com_raw_10b,
        input bit [9:0] skp1_raw_10b
    );
        bit [9:0] raw_10b;
        bit [7:0] dec_byte;
        bit is_k;
        bit code_err;
        running_disparity_e matched_rd;

        dec_byte = decode_8b10b_symbol(com_raw_10b, is_k, code_err, matched_rd);
        if (!code_err) lane_disparity[lane_idx] = matched_rd;

        dec_byte = decode_8b10b_symbol(skp1_raw_10b, is_k, code_err, matched_rd);
        if (!code_err) lane_disparity[lane_idx] = matched_rd;

        if (code_err || !is_k || dec_byte != SKP_SYMBOL) begin
            `uvm_warning(name, $sformatf("Invalid SKP symbol 1 on lane %0d", lane_idx))
        end

        for (int i = 0; i < 2; i++) begin
            sample_symbol_10b(lane_idx, raw_10b);
            dec_byte = decode_8b10b_symbol(raw_10b, is_k, code_err, matched_rd);
            if (!code_err) lane_disparity[lane_idx] = matched_rd;
            if (code_err || !is_k || dec_byte != SKP_SYMBOL) begin
                `uvm_warning(name, $sformatf("Invalid SKP symbol %0d on lane %0d", i + 2, lane_idx))
            end
        end

        skp_rx_count++;
        `uvm_info(name, $sformatf("Lane %0d: SKP Ordered Set", lane_idx), UVM_HIGH)
    endtask : capture_skp

    task automatic monitor_lane
    (
        input int lane_idx
    );
        bit [9:0] sym0;
        bit [9:0] sym1;
        bit is_k0;
        bit is_k1;
        bit err0;
        bit err1;
        bit [7:0] dec0;
        bit [7:0] dec1;
        bit com_found;
        running_disparity_e matched_rd0;
        running_disparity_e matched_rd1;

        sample_symbol_10b(lane_idx, sym0);
        dec0 = decode_8b10b_symbol(sym0, is_k0, err0, matched_rd0);
        com_found = is_k0 && !err0 && dec0 == COM_SYMBOL;

        if (com_found) begin
            sample_symbol_10b(lane_idx, sym1);
            dec1 = decode_8b10b_symbol(sym1, is_k1, err1, matched_rd1);
            if (is_k1 && !err1 && dec1 == SKP_SYMBOL) capture_skp(lane_idx, sym0, sym1);
            else capture_ts(lane_idx, sym0, sym1);
        end
        else begin
            if (!err0) lane_disparity[lane_idx] = matched_rd0;
            if (err0) `uvm_warning(name, $sformatf("8b/10b violation lane=%0d", lane_idx))
            capture_idle(lane_idx, dec0);
        end
    endtask : monitor_lane

    function automatic bit check_electrical_idle_exit_any_lane();
        for (int lane = 0; lane < get_active_lanes(); lane++) begin
            if ((rcMonCb.RX_P[lane] == 1'b1 && rcMonCb.RX_N[lane] == 1'b0) ||
                (rcMonCb.RX_P[lane] == 1'b0 && rcMonCb.RX_N[lane] == 1'b1)) return 1'b1;
        end
        return 1'b0;
    endfunction : check_electrical_idle_exit_any_lane

    function automatic bit [PCIE_MAX_LANES-1:0] sample_rx_detect_status();
        bit [PCIE_MAX_LANES-1:0] detected_mask;
        detected_mask = '0;
        for (int lane = 0; lane < get_active_lanes(); lane++) begin
            if ((rcMonCb.RX_P[lane] == 1'b1 && rcMonCb.RX_N[lane] == 1'b0) ||
                (rcMonCb.RX_P[lane] == 1'b0 && rcMonCb.RX_N[lane] == 1'b1)) detected_mask[lane] = 1'b1;
        end
        return detected_mask;
    endfunction : sample_rx_detect_status

    task automatic monitor_detect_quiet
    (
        output detect_substate_e next_substate
    );
        `uvm_info(name, "Monitoring Detect.Quiet", UVM_MEDIUM)
        repeat (rc_agent_cfg_h.detect_timeout_cycles) begin
            @(rcMonCb);
            if (check_electrical_idle_exit_any_lane()) begin
                `uvm_info(name, "Electrical Idle Exit -> Detect.Active", UVM_HIGH)
                next_substate = DETECT_ACTIVE;
                return;
            end
        end
        next_substate = DETECT_ACTIVE;
    endtask : monitor_detect_quiet

    task automatic monitor_detect_active
    (
        output ltssm_state_e next_state
    );
        bit [PCIE_MAX_LANES-1:0] detected_mask;
        bit [PCIE_MAX_LANES-1:0] expected_mask;

        `uvm_info(name, "Monitoring Detect.Active", UVM_MEDIUM)
        expected_mask = '0;
        for (int lane = 0; lane < get_active_lanes(); lane++) expected_mask[lane] = 1'b1;

        detected_mask = sample_rx_detect_status();
        if (detected_mask == expected_mask) begin
            `uvm_info(name, "RX detected on all lanes -> POLLING", UVM_LOW)
            next_state = POLLING_ST;
            return;
        end
        if (detected_mask == '0) begin
            next_state = DETECT_ST;
            return;
        end

        repeat (rc_agent_cfg_h.detect_timeout_cycles) @(rcMonCb);
        detected_mask = sample_rx_detect_status();
        if (detected_mask == expected_mask) next_state = POLLING_ST;
        else next_state = DETECT_ST;
    endtask : monitor_detect_active

    task automatic monitor_polling_active
    (
        output polling_substate_e next_substate,
        output ltssm_state_e next_state
    );
        bit [9:0] sym0;
        bit [9:0] sym1;
        bit is_k0;
        bit err0;
        bit [7:0] dec0;
        running_disparity_e matched_rd0;
        ts_ordered_set_bytes_t ts_bytes;
        bit ts_valid;
        int unsigned consec_ts2_match_cnt;
        time start_time;
        bit lock_found;
        bit [9:0] locked_code [0:PCIE_MAX_LANES-1];
        bit have_sym0;

        `uvm_info(name, "ENTER Polling.Active", UVM_LOW)

        ts1_rx_count = 0;
        consec_ts2_match_cnt = 0;
        consec_invalid_rx_count = 0;
        start_time = $time;
        have_sym0 = 1'b0;

        if (!symbol_lock_acquired) begin
            acquire_symbol_lock(locked_code, lock_found);
            if (!lock_found) begin
                `uvm_error(name, "Polling.Active: symbol lock failed")
                next_state = DETECT_ST;
                return;
            end
            sym0 = locked_code[0];
            have_sym0 = 1'b1;
        end

        forever begin
            if (!have_sym0) sample_symbol_10b(0, sym0);
            have_sym0 = 1'b0;

            dec0 = decode_8b10b_symbol(sym0, is_k0, err0, matched_rd0);

            if (is_k0 && !err0 && dec0 == COM_SYMBOL) begin
                lane_disparity[0] = matched_rd0;
                sample_symbol_10b(0, sym1);
                capture_ts_bytes(0, sym1, ts_bytes, ts_valid);

                if (ts_valid && ts_bytes.sym6_15_identifier[0] == TS1_ID_BYTE) begin
                    ts1_rx_count++;
                    consec_ts2_match_cnt = 0;
                    `uvm_info(name, $sformatf("Polling.Active: TS1 count=%0d", ts1_rx_count), UVM_HIGH)
                end
                else if (ts_valid && ts_bytes.sym6_15_identifier[0] == TS2_ID_BYTE) begin
                    consec_ts2_match_cnt++;
                    `uvm_info(name, $sformatf("Polling.Active: TS2=%0d/%0d", consec_ts2_match_cnt, CONSEC_TS_COUNT), UVM_HIGH)
                end
                else begin
                    consec_ts2_match_cnt = 0;
                end
                consec_invalid_rx_count = 0;
            end
            else begin
                consec_ts2_match_cnt = 0;
                consec_invalid_rx_count++;
                if (consec_invalid_rx_count >= MAX_CONSEC_INVALID_RX) begin
                    `uvm_warning(name, "Polling.Active: symbol re-lock")
                    symbol_lock_acquired = 1'b0;
                    consec_invalid_rx_count = 0;
                    acquire_symbol_lock(locked_code, lock_found);
                    if (!lock_found) begin
                        next_state = DETECT_ST;
                        return;
                    end
                    sym0 = locked_code[0];
                    have_sym0 = 1'b1;
                end
            end

            if (consec_ts2_match_cnt >= CONSEC_TS_COUNT) begin
                `uvm_info(name, "Polling.Active -> Polling.Configuration", UVM_LOW)
                next_substate = POLLING_CONFIG;
                next_state = POLLING_ST;
                return;
            end

            if (($time - start_time) >= (POLLING_TIMEOUT_MS * 1ms)) begin
                `uvm_error(name, "Polling.Active Monitor Timeout")
                next_state = DETECT_ST;
                return;
            end
        end
    endtask : monitor_polling_active

    task automatic monitor_polling_configuration
    (
        output ltssm_state_e next_state
    );
        bit [9:0] raw_ts [0:PCIE_MAX_LANES-1];
        bit [9:0] raw_sym0 [0:PCIE_MAX_LANES-1];
        bit [9:0] raw_sym1 [0:PCIE_MAX_LANES-1];
        bit [7:0] dec_byte [0:PCIE_MAX_LANES-1];
        bit is_k [0:PCIE_MAX_LANES-1];
        bit code_err [0:PCIE_MAX_LANES-1];
        running_disparity_e matched_rd [0:PCIE_MAX_LANES-1];
        bit all_ts2;
        int unsigned consec_match_cnt;
        time start_time;
        bit lock_found;
        bit [9:0] locked_code [0:PCIE_MAX_LANES-1];

        `uvm_info(name, "ENTER Polling.Configuration", UVM_LOW)

        consec_match_cnt = 0;
        consec_invalid_rx_count = 0;
        start_time = $time;

        if (!symbol_lock_acquired) begin
            acquire_symbol_lock(locked_code, lock_found);
            if (!lock_found) begin
                `uvm_error(name, "Polling.Configuration: lock failed")
                next_state = DETECT_ST;
                return;
            end
        end

        forever begin
            sample_all_lanes_symbol_10b(raw_sym0);
            all_ts2 = 1'b1;

            for (int l = 0; l < get_active_lanes(); l++) begin
                dec_byte[l] = decode_8b10b_symbol(raw_sym0[l], is_k[l], code_err[l], matched_rd[l]);
                if (code_err[l] || !is_k[l] || dec_byte[l] != COM_SYMBOL) all_ts2 = 1'b0;
                else lane_disparity[l] = matched_rd[l];
            end

            if (all_ts2) begin
                sample_all_lanes_symbol_10b(raw_sym1);
                for (int l = 0; l < get_active_lanes(); l++) begin
                    dec_byte[l] = decode_8b10b_symbol(raw_sym1[l], is_k[l], code_err[l], matched_rd[l]);
                    if (code_err[l]) all_ts2 = 1'b0;
                    else lane_disparity[l] = matched_rd[l];
                end

                for (int s = 2; s < TS_OS_LENGTH; s++) begin
                    sample_all_lanes_symbol_10b(raw_ts);
                    for (int l = 0; l < get_active_lanes(); l++) begin
                        dec_byte[l] = decode_8b10b_symbol(raw_ts[l], is_k[l], code_err[l], matched_rd[l]);
                        if (code_err[l]) all_ts2 = 1'b0;
                        else lane_disparity[l] = matched_rd[l];
                        if (s == 6 && dec_byte[l] != TS2_ID_BYTE) all_ts2 = 1'b0;
                    end
                end

                if (all_ts2) begin
                    consec_match_cnt++;
                    ts2_rx_count_complete++;
                    `uvm_info(name, $sformatf("Polling.Configuration: valid TS2 %0d/%0d", consec_match_cnt, CONSEC_TS2_COMPLETE), UVM_HIGH)
                end
                else begin
                    consec_match_cnt = 0;
                end
                consec_invalid_rx_count = 0;
            end
            else begin
                consec_match_cnt = 0;
                consec_invalid_rx_count++;
                if (consec_invalid_rx_count >= MAX_CONSEC_INVALID_RX) begin
                    `uvm_warning(name, "Polling.Configuration: re-lock")
                    symbol_lock_acquired = 1'b0;
                    consec_invalid_rx_count = 0;
                    acquire_symbol_lock(locked_code, lock_found);
                    if (!lock_found) begin
                        next_state = DETECT_ST;
                        return;
                    end
                end
            end

            if (consec_match_cnt >= CONSEC_TS2_COMPLETE) begin
                `uvm_info(name, "Polling.Configuration -> Configuration", UVM_LOW)
                next_state = CONFIG_ST;
                return;
            end

            if (($time - start_time) >= (CONFIG_TIMEOUT_MS * 1ms)) begin
                `uvm_error(name, "Polling.Configuration Monitor Timeout")
                next_state = DETECT_ST;
                return;
            end
        end
    endtask : monitor_polling_configuration

    task automatic monitor_receive_ts
    (
        output ts_ordered_set_bytes_t bytes,
        output bit [7:0] rx_lane_number [0:PCIE_MAX_LANES-1],
        output bit valid
    );
        bit [9:0] raw_symbol [0:PCIE_MAX_LANES-1];
        bit [7:0] sym_array [0:TS_OS_LENGTH-1];
        bit is_k [0:PCIE_MAX_LANES-1];
        bit code_err [0:PCIE_MAX_LANES-1];
        running_disparity_e matched_rd [0:PCIE_MAX_LANES-1];
        bit all_valid;
        bit lock_found;
        bit [9:0] locked_code [0:PCIE_MAX_LANES-1];

        valid = 1'b1;
        bytes = '0;
        foreach (rx_lane_number[l]) rx_lane_number[l] = PAD_SYMBOL;

        if (!symbol_lock_acquired) begin
            acquire_symbol_lock(locked_code, lock_found);
            if (!lock_found) begin
                valid = 1'b0;
                return;
            end
            for (int l = 0; l < get_active_lanes(); l++) begin
                raw_symbol[l] = locked_code[l];
                sym_array[0] = decode_8b10b_symbol(raw_symbol[l], is_k[l], code_err[l], matched_rd[l]);
                if (code_err[l] || !is_k[l] || sym_array[0] != COM_SYMBOL) valid = 1'b0;
                else lane_disparity[l] = matched_rd[l];
            end
        end
        else begin
            sample_all_lanes_symbol_10b(raw_symbol);
            for (int l = 0; l < get_active_lanes(); l++) begin
                sym_array[0] = decode_8b10b_symbol(raw_symbol[l], is_k[l], code_err[l], matched_rd[l]);
                if (code_err[l] || !is_k[l] || sym_array[0] != COM_SYMBOL) valid = 1'b0;
                else lane_disparity[l] = matched_rd[l];
            end
        end

        for (int s = 1; s < TS_OS_LENGTH; s++) begin
            sample_all_lanes_symbol_10b(raw_symbol);
            all_valid = 1'b1;
            for (int l = 0; l < get_active_lanes(); l++) begin
                bit [7:0] temp_byte;
                temp_byte = decode_8b10b_symbol(raw_symbol[l], is_k[l], code_err[l], matched_rd[l]);
                if (code_err[l]) begin
                    valid = 1'b0;
                    all_valid = 1'b0;
                end
                else begin
                    lane_disparity[l] = matched_rd[l];
                end
                if (s == 2) rx_lane_number[l] = temp_byte;
                if (l == 0) sym_array[s] = temp_byte;
            end
        end

        bytes.sym0_com           = sym_array[0];
        bytes.sym1_link_number   = sym_array[1];
        bytes.sym2_lane_number   = rx_lane_number[0];
        bytes.sym3_n_fts         = sym_array[3];
        bytes.sym4_data_rate_id  = sym_array[4];
        bytes.sym5_training_ctrl = sym_array[5];
        for (int i = 0; i < 10; i++) bytes.sym6_15_identifier[i] = sym_array[6+i];

        if (sym_array[0] != COM_SYMBOL) valid = 1'b0;

        if (!valid) consec_invalid_rx_count++;
        else consec_invalid_rx_count = 0;

        if (consec_invalid_rx_count >= MAX_CONSEC_INVALID_RX) begin
            `uvm_warning(name, "monitor_receive_ts: symbol re-lock")
            symbol_lock_acquired = 1'b0;
            consec_invalid_rx_count = 0;
        end
    endtask : monitor_receive_ts

    function automatic bit detect_lane_reversal
    (
        input bit [7:0] ep_lane [0:PCIE_MAX_LANES-1]
    );
        for (int l = 0; l < get_active_lanes(); l++)
            if (ep_lane[l] !== (get_active_lanes() - 1 - l)) return 1'b0;
        return 1'b1;
    endfunction : detect_lane_reversal

    task automatic monitor_configuration_linkwidth_start
    (
        output config_substate_e next_config_substate,
        output ltssm_state_e next_state
    );
        ts_ordered_set_bytes_t rx_bytes;
        bit [7:0] rx_lane_number [0:PCIE_MAX_LANES-1];
        bit rx_valid;
        int unsigned consec_link_match_cnt;
        int unsigned ts_attempt_cnt;

        `uvm_info(name, "ENTER Configuration.Linkwidth.Start", UVM_LOW)
        consec_link_match_cnt = 0;
        ts_attempt_cnt = 0;
        configured_link_number = rc_agent_cfg_h.link_number;

        forever begin
            monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
            ts_attempt_cnt++;

            if (rx_valid && rx_bytes.sym6_15_identifier[0] == TS1_ID_BYTE &&
                rx_bytes.sym1_link_number == configured_link_number &&
                rx_lane_number[0] == PAD_SYMBOL) begin
                consec_link_match_cnt++;
                `uvm_info(name, $sformatf("Linkwidth.Start TS1 %0d/%0d", consec_link_match_cnt, CONSEC_TS_REQUIRED), UVM_HIGH)
            end
            else begin
                consec_link_match_cnt = 0;
            end

            if (consec_link_match_cnt >= CONSEC_TS_REQUIRED) begin
                `uvm_info(name, "Configuration.Linkwidth.Start COMPLETE", UVM_LOW)
                next_config_substate = CFG_LINKWIDTH_ACCEPT;
                next_state = CONFIG_ST;
                return;
            end

            if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
                `uvm_error(name, "Configuration.Linkwidth.Start Timeout")
                next_state = DETECT_ST;
                return;
            end
        end
    endtask : monitor_configuration_linkwidth_start

    task automatic monitor_configuration_linkwidth_accept
    (
        output config_substate_e next_config_substate,
        output ltssm_state_e next_state
    );
        ts_ordered_set_bytes_t rx_bytes;
        bit [7:0] rx_lane_number [0:PCIE_MAX_LANES-1];
        bit rx_valid;
        int unsigned ts_attempt_cnt;
        bit use_reversal;
        bit valid_group;

        `uvm_info(name, "ENTER Configuration.Linkwidth.Accept", UVM_LOW)
        ts_attempt_cnt = 0;

        forever begin
            monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
            ts_attempt_cnt++;

            if (rx_valid && rx_bytes.sym6_15_identifier[0] == TS1_ID_BYTE) begin
                use_reversal = detect_lane_reversal(rx_lane_number);
                valid_group = 1'b1;

                for (int l = 0; l < get_active_lanes(); l++) begin
                    bit [7:0] lane_num;
                    if (use_reversal) lane_num = rx_lane_number[get_active_lanes()-1-l];
                    else lane_num = rx_lane_number[l];
                    configured_lane_number[l] = lane_num;
                    if (lane_num == PAD_SYMBOL) valid_group = 1'b0;
                end

                if (valid_group) begin
                    `uvm_info(name, "Configuration.Linkwidth.Accept COMPLETE", UVM_LOW)
                    next_config_substate = CFG_LANENUM_WAIT;
                    next_state = CONFIG_ST;
                    return;
                end
            end

            if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
                `uvm_error(name, "Configuration.Linkwidth.Accept Timeout")
                next_state = DETECT_ST;
                return;
            end
        end
    endtask : monitor_configuration_linkwidth_accept

    task automatic monitor_configuration_lanenum_wait
    (
        output config_substate_e next_config_substate,
        output ltssm_state_e next_state
    );
        ts_ordered_set_bytes_t rx_bytes;
        bit [7:0] rx_lane_number [0:PCIE_MAX_LANES-1];
        bit rx_valid;
        int unsigned consec_match_cnt;
        int unsigned ts_attempt_cnt;
        bit valid_lane_group;

        `uvm_info(name, "ENTER Configuration.Lanenum.Wait", UVM_LOW)
        consec_match_cnt = 0;
        ts_attempt_cnt = 0;

        forever begin
            monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
            ts_attempt_cnt++;

            valid_lane_group = 1'b1;
            if (!rx_valid) valid_lane_group = 1'b0;
            if (rx_valid && rx_bytes.sym6_15_identifier[0] != TS1_ID_BYTE) valid_lane_group = 1'b0;
            if (rx_valid && rx_bytes.sym1_link_number != configured_link_number) valid_lane_group = 1'b0;

            for (int l = 0; l < get_active_lanes(); l++)
                if (rx_lane_number[l] != configured_lane_number[l]) valid_lane_group = 1'b0;

            if (valid_lane_group) consec_match_cnt++;
            else consec_match_cnt = 0;

            if (consec_match_cnt >= CONSEC_TS_REQUIRED) begin
                `uvm_info(name, "Configuration.Lanenum.Wait COMPLETE", UVM_LOW)
                next_config_substate = CFG_COMPLETE;
                next_state = CONFIG_ST;
                return;
            end

            if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
                `uvm_error(name, "Configuration.Lanenum.Wait Timeout")
                next_state = DETECT_ST;
                return;
            end
        end
    endtask : monitor_configuration_lanenum_wait

    task automatic monitor_configuration_lanenum_accept
    (
        output config_substate_e next_config_substate,
        output ltssm_state_e next_state
    );
        ts_ordered_set_bytes_t rx_bytes;
        bit [7:0] rx_lane_number [0:PCIE_MAX_LANES-1];
        bit rx_valid;
        int unsigned consec_match_cnt;
        int unsigned ts_attempt_cnt;
        bit valid_group;
        bit smaller_link_detected;
        bit any_non_pad;

        `uvm_info(name, "ENTER Configuration.Lanenum.Accept", UVM_LOW)
        consec_match_cnt = 0;
        ts_attempt_cnt = 0;

        forever begin
            monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
            ts_attempt_cnt++;

            if (rx_valid) begin
                valid_group = 1'b1;
                if (rx_bytes.sym6_15_identifier[0] != TS1_ID_BYTE) valid_group = 1'b0;
                if (rx_bytes.sym1_link_number != configured_link_number) valid_group = 1'b0;

                for (int l = 0; l < get_active_lanes(); l++)
                    if (rx_lane_number[l] != configured_lane_number[l]) valid_group = 1'b0;

                smaller_link_detected = 1'b0;
                for (int l = 0; l < get_active_lanes(); l++)
                    if ((configured_lane_number[l] != PAD_SYMBOL) && (rx_lane_number[l] == PAD_SYMBOL))
                        smaller_link_detected = 1'b1;

                if (valid_group) consec_match_cnt++;
                else consec_match_cnt = 0;

                if (consec_match_cnt >= CONSEC_TS_REQUIRED) begin
                    next_config_substate = CFG_COMPLETE;
                    next_state = CONFIG_ST;
                    return;
                end

                if (smaller_link_detected) begin
                    `uvm_info(name, "Reduced Link Width observed", UVM_LOW)
                    for (int l = 0; l < get_active_lanes(); l++)
                        configured_lane_number[l] = rx_lane_number[l];
                    next_config_substate = CFG_LANENUM_WAIT;
                    next_state = CONFIG_ST;
                    return;
                end

                any_non_pad = 1'b0;
                for (int l = 0; l < get_active_lanes(); l++)
                    if (rx_lane_number[l] != PAD_SYMBOL) any_non_pad = 1'b1;

                if (!any_non_pad) begin
                    `uvm_warning(name, "All lanes PAD in Lanenum.Accept")
                    next_state = DETECT_ST;
                    return;
                end
            end

            if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
                `uvm_error(name, "Configuration.Lanenum.Accept Timeout")
                next_state = DETECT_ST;
                return;
            end
        end
    endtask : monitor_configuration_lanenum_accept

    task automatic monitor_configuration_complete
    (
        output config_substate_e next_config_substate,
        output ltssm_state_e next_state
    );
        ts_ordered_set_bytes_t rx_bytes;
        bit [7:0] rx_lane_number [0:PCIE_MAX_LANES-1];
        bit rx_valid;
        int unsigned consec_ts2_cnt;
        int unsigned ts_attempt_cnt;
        bit valid_group;

        `uvm_info(name, "ENTER Configuration.Complete", UVM_LOW)
        consec_ts2_cnt = 0;
        ts_attempt_cnt = 0;

        forever begin
            monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
            ts_attempt_cnt++;

            valid_group = 1'b1;
            if (!rx_valid) valid_group = 1'b0;
            if (rx_valid && rx_bytes.sym6_15_identifier[0] != TS2_ID_BYTE) valid_group = 1'b0;
            if (rx_valid && rx_bytes.sym1_link_number != configured_link_number) valid_group = 1'b0;

            for (int l = 0; l < get_active_lanes(); l++)
                if (rx_lane_number[l] != configured_lane_number[l]) valid_group = 1'b0;

            if (valid_group) consec_ts2_cnt++;
            else consec_ts2_cnt = 0;

            `uvm_info(name, $sformatf("Configuration.Complete TS2=%0d/%0d", consec_ts2_cnt, CONSEC_TS_REQUIRED), UVM_HIGH)

            if (consec_ts2_cnt >= CONSEC_TS_REQUIRED) begin
                `uvm_info(name, "Configuration.Complete COMPLETE -> Idle", UVM_LOW)
                next_config_substate = CFG_IDLE;
                next_state = CONFIG_ST;
                return;
            end

            if (ts_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
                `uvm_error(name, "Configuration.Complete Timeout")
                next_state = DETECT_ST;
                return;
            end
        end
    endtask : monitor_configuration_complete

    task automatic monitor_configuration_idle
    (
        output ltssm_state_e next_state
    );
        bit [9:0] raw_symbol [0:PCIE_MAX_LANES-1];
        bit [7:0] rx_byte [0:PCIE_MAX_LANES-1];
        bit is_k [0:PCIE_MAX_LANES-1];
        bit code_err [0:PCIE_MAX_LANES-1];
        running_disparity_e matched_rd [0:PCIE_MAX_LANES-1];
        bit all_lanes_idle;
        int unsigned consec_idle_cnt;
        int unsigned idle_attempt_cnt;
        bit lock_found;
        bit [9:0] locked_code [0:PCIE_MAX_LANES-1];
        bit have_locked_symbols;

        `uvm_info(name, "ENTER Configuration.Idle", UVM_LOW)
        consec_idle_cnt = 0;
        idle_attempt_cnt = 0;
        consec_invalid_rx_count = 0;

        symbol_lock_acquired = 1'b0;
        acquire_idle_symbol_lock(locked_code, lock_found);
        if (!lock_found) begin
            `uvm_error(name, "Configuration.Idle: IDLE lock failed")
            next_state = DETECT_ST;
            return;
        end
        have_locked_symbols = 1'b1;

        forever begin
            all_lanes_idle = 1'b1;

            if (have_locked_symbols) begin
                for (int l = 0; l < get_active_lanes(); l++) begin
                    rx_byte[l] = decode_8b10b_symbol(locked_code[l], is_k[l], code_err[l], matched_rd[l]);
                    if (!code_err[l]) lane_disparity[l] = matched_rd[l];
                    if (code_err[l] || is_k[l] || rx_byte[l] != IDLE_SYMBOL) all_lanes_idle = 1'b0;
                end
                have_locked_symbols = 1'b0;
            end
            else begin
                sample_all_lanes_symbol_10b(raw_symbol);
                for (int l = 0; l < get_active_lanes(); l++) begin
                    rx_byte[l] = decode_8b10b_symbol(raw_symbol[l], is_k[l], code_err[l], matched_rd[l]);
                    if (!code_err[l]) lane_disparity[l] = matched_rd[l];
                    if (code_err[l] || is_k[l] || rx_byte[l] != IDLE_SYMBOL) all_lanes_idle = 1'b0;
                end
            end

            idle_attempt_cnt++;
            if (all_lanes_idle) consec_idle_cnt++;
            else consec_idle_cnt = 0;

            if (!all_lanes_idle) begin
                consec_invalid_rx_count++;
                if (consec_invalid_rx_count >= MAX_CONSEC_INVALID_RX) begin
                    `uvm_warning(name, "Configuration.Idle: re-lock IDLE")
                    consec_invalid_rx_count = 0;
                    acquire_idle_symbol_lock(locked_code, lock_found);
                    if (!lock_found) begin
                        `uvm_error(name, "Configuration.Idle: re-lock failed")
                        next_state = DETECT_ST;
                        return;
                    end
                    have_locked_symbols = 1'b1;
                end
            end
            else begin
                consec_invalid_rx_count = 0;
            end

            if (consec_idle_cnt >= MIN_IDLE_RX) begin
                `uvm_info(name, $sformatf("Configuration.Idle COMPLETE -> L0 after %0d IDLE symbols", consec_idle_cnt), UVM_LOW)
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

    //-------------------------------------------------------
    // Task: monitor_l0  [FIXED - symbol lock acquisition added]
    //
    // Previously this task sampled raw bits with no alignment
    // search at all, unlike every other task in this file. It
    // also had no way to re-synchronize after a slip. Both are
    // fixed here, matching the pattern used in monitor_polling_active.
    //-------------------------------------------------------
    task automatic monitor_l0
    (
        output ltssm_state_e next_state
    );
        bit [9:0] raw_symbol;
        bit [7:0] rx_byte;
        bit rx_is_k;
        bit code_err;
        running_disparity_e matched_rd;

        int unsigned consec_rx_errors;
        int unsigned idle_symbol_count;
        time last_valid_rx_time;

        bit lock_found;
        bit [9:0] locked_code [0:PCIE_MAX_LANES-1];
        bit have_sym0;
    bit [9:0] ts_raw;
    bit [7:0] ts_byte;
    bit       ts_k;
    bit       ts_err;
    running_disparity_e ts_rd;

        localparam int unsigned MAX_CONSEC_RX_ERRORS = 8;
        localparam int unsigned MAX_IDLE_SYMBOLS = 1000;
        localparam int unsigned RELOCK_THRESHOLD = 3;

        `uvm_info(name, "ENTER L0", UVM_LOW)

        next_state = L0_ST;
        consec_rx_errors = 0;
        idle_symbol_count = 0;
        last_valid_rx_time = $time;
        have_sym0 = 1'b0;

        if (!symbol_lock_acquired) begin
            acquire_symbol_lock(locked_code, lock_found);
            if (!lock_found) begin
                `uvm_error(name, "L0: could not acquire symbol lock")
                next_state = RECOVERY_ST;
                return;
            end
            raw_symbol = locked_code[0];
            have_sym0  = 1'b1;
        end

        forever begin

            if (!have_sym0) begin
                sample_symbol_10b(0, raw_symbol);
            end
            have_sym0 = 1'b0;

            rx_byte = decode_8b10b_symbol(raw_symbol, rx_is_k, code_err, matched_rd);

            if (!code_err) begin
                lane_disparity[0] = matched_rd;
                consec_rx_errors  = 0;
                last_valid_rx_time = $time;
            end
            else begin
                consec_rx_errors++;
                `uvm_warning(name, $sformatf("L0: Invalid 8b/10b symbol, error count=%0d", consec_rx_errors));
            end

            if (!code_err && !rx_is_k && rx_byte == IDLE_SYMBOL) begin
                idle_symbol_count++;
            end
            else begin
                idle_symbol_count = 0;
            end

            //-----------------------------------------------------
            // Re-lock on sustained failure, same watchdog pattern
            // used everywhere else in this file.
            //-----------------------------------------------------
      //-----------------------------------------------------
      // Recovery entry: partner started a TS1/TS2 (COM ... sym6 = TS id).
      // SKP ordered sets also start with COM but sym1 is K28.0, so skip.
      //-----------------------------------------------------
      if (!code_err && rx_is_k && rx_byte == COM_SYMBOL) begin
        sample_symbol_10b(0, ts_raw);
        ts_byte = decode_8b10b_symbol(ts_raw, ts_k, ts_err, ts_rd);
        if (!ts_err && !ts_k) begin
          for (int s = 2; s <= 6; s++) begin
            sample_symbol_10b(0, ts_raw);
            ts_byte = decode_8b10b_symbol(ts_raw, ts_k, ts_err, ts_rd);
          end
          if (!ts_err && !ts_k && (ts_byte == TS1_ID_BYTE || ts_byte == TS2_ID_BYTE)) begin
            `uvm_info(name, "L0: partner is sending TS1/TS2 -> Recovery", UVM_LOW)
            symbol_lock_acquired = 1'b0;
            next_state = RECOVERY_ST;
            return;
          end
        end
      end

            if (consec_rx_errors >= RELOCK_THRESHOLD) begin
                `uvm_warning(name, $sformatf("L0: %0d consecutive invalid symbols - forcing symbol re-lock", consec_rx_errors))
                symbol_lock_acquired = 1'b0;
                acquire_symbol_lock(locked_code, lock_found);
                if (!lock_found) begin
                    `uvm_warning(name, "L0: could not re-acquire symbol lock -> Recovery")
                    next_state = RECOVERY_ST;
                    return;
                end
                raw_symbol = locked_code[0];
                have_sym0  = 1'b1;
                consec_rx_errors = 0;
            end

            if (consec_rx_errors >= MAX_CONSEC_RX_ERRORS) begin
                `uvm_warning(name, "L0: RX error threshold reached -> Recovery")
                next_state = RECOVERY_ST;
                return;
            end

            if (idle_symbol_count >= MAX_IDLE_SYMBOLS) begin
                `uvm_warning(name, "L0: Excessive IDLE detected -> Recovery")
                next_state = RECOVERY_ST;
                return;
            end

        end
    endtask : monitor_l0


    //=======================================================
    //  RECOVERY  (added) - passive monitor, one task per substate.
    //  All tasks share one signature so the proxy can dispatch uniformly.
    //  Timeout -> next_state = DETECT_ST (uvm_error), same as the other monitor tasks.
    //=======================================================

    task automatic recovery_entry();
        changed_speed_recovery       = 1'b0;
        successful_speed_negotiation = 1'b0;
        directed_speed_change        = 1'b0;
        current_recovery_substate    = RECOVERY_RCVR_LOCK;
        `uvm_info(name, $sformatf("L0 -> Recovery entry at %s", current_speed.name()), UVM_LOW)
    endtask : recovery_entry

    // 16-symbol Modified TS check over the sliding window mod_win[]
    function automatic bit mod_window_ok(output modified_ts_bytes_t b);
        bit ok;
        ok = 1'b1;
        b  = '0;
        for (int i = 0; i < 16; i++) if (mod_win_err[i]) ok = 1'b0;
        if (mod_win[7]  != (mod_win[0]^mod_win[1]^mod_win[2]^mod_win[3]^mod_win[4]^mod_win[5]^mod_win[6])) ok = 1'b0;
        for (int i = 0; i < 7; i++) if (mod_win[8+i] != mod_win[i]) ok = 1'b0;
        if (mod_win[15] != (mod_win[8]^mod_win[9]^mod_win[10]^mod_win[11]^mod_win[12]^mod_win[13]^mod_win[14])) ok = 1'b0;
        b.id           = mod_win[0];
        b.link_number  = mod_win[1];
        b.lane_number  = mod_win[2];
        b.n_fts        = mod_win[3];
        b.data_rate_id = mod_win[4];
        b.ec_byte      = mod_win[5];
        b.payload      = mod_win[6];
        return ok;
    endfunction : mod_window_ok

    task automatic monitor_receive_modified_ts(output modified_ts_bytes_t bytes, output bit valid);
        bit [9:0] raw_symbol;
        bit       is_k;
        bit       code_err;
        running_disparity_e matched_rd;
        bit [7:0] dec;

        valid = 1'b0;
        bytes = '0;

        for (int s = 0; s < 16; s++) begin
            sample_symbol_10b(0, raw_symbol);
            dec = decode_8b10b_symbol(raw_symbol, is_k, code_err, matched_rd);
            mod_win[s]     = dec;
            mod_win_err[s] = (code_err || is_k);
            if (!code_err) lane_disparity[0] = matched_rd;
        end
        if (mod_window_ok(bytes)) begin valid = 1'b1; return; end

        // not aligned to a TS boundary: slide one symbol at a time
        for (int t = 0; t < 32; t++) begin
            for (int s = 0; s < 15; s++) begin
                mod_win[s]     = mod_win[s+1];
                mod_win_err[s] = mod_win_err[s+1];
            end
            sample_symbol_10b(0, raw_symbol);
            dec = decode_8b10b_symbol(raw_symbol, is_k, code_err, matched_rd);
            mod_win[15]     = dec;
            mod_win_err[15] = (code_err || is_k);
            if (!code_err) lane_disparity[0] = matched_rd;
            if (mod_window_ok(bytes)) begin valid = 1'b1; return; end
        end
    endtask : monitor_receive_modified_ts

    // Wait for CONSEC_TS_COUNT matching TS (Modified TS at Gen3+, standard TS below).
    // ts2_only=0: TS1 or TS2 (RcvrLock).  ts2_only=1: TS2 only (RcvrCfg).
    task automatic recovery_wait_ts(input bit ts2_only, input string tag, output bit ok);
        ts_ordered_set_bytes_t rx_bytes;
        bit [7:0] rx_lane_number [0:PCIE_MAX_LANES-1];
        bit rx_valid;
        int unsigned cnt;
        time start_time;
        bit lane_match;
        modified_ts_bytes_t mod_rx;
        bit mod_valid;

        ok = 1'b0;
        cnt = 0;
        start_time = $time;

        forever begin
            if (current_speed >= EQ_REQUIRED_MIN_GEN) begin
                monitor_receive_modified_ts(mod_rx, mod_valid);
                lane_match = (mod_rx.lane_number == configured_lane_number[0]);
                if (mod_valid &&
                        ((ts2_only) ? (mod_rx.id == MOD_TS2_ID) : (mod_rx.id == MOD_TS1_ID || mod_rx.id == MOD_TS2_ID)) &&
                        mod_rx.data_rate_id[7] == directed_speed_change &&
                        mod_rx.link_number == configured_link_number && lane_match)
                    cnt++;
                else cnt = 0;
            end
            else begin
                monitor_receive_ts(rx_bytes, rx_lane_number, rx_valid);
                lane_match = 1'b1;
                for (int l = 0; l < get_active_lanes(); l++)
                    if (rx_lane_number[l] != configured_lane_number[l]) lane_match = 1'b0;
                if (rx_valid &&
                        ((ts2_only) ? (rx_bytes.sym6_15_identifier[0] == TS2_ID_BYTE)
                                                : (rx_bytes.sym6_15_identifier[0] == TS1_ID_BYTE || rx_bytes.sym6_15_identifier[0] == TS2_ID_BYTE)) &&
                        rx_bytes.sym4_data_rate_id[7] == directed_speed_change &&
                        rx_bytes.sym1_link_number == configured_link_number && lane_match)
                    cnt++;
                else cnt = 0;
            end

            if (cnt >= CONSEC_TS_COUNT) begin ok = 1'b1; return; end

            if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
                `uvm_error(name, $sformatf("%s Monitor Timeout - returning to Detect", tag))
                return;
            end
        end
    endtask : recovery_wait_ts

    task automatic monitor_recovery_rcvr_lock(output recovery_substate_e next_recovery_substate,
                                                                                        output ltssm_state_e next_state);
        bit ok;
        current_recovery_substate = RECOVERY_RCVR_LOCK;
        next_recovery_substate    = RECOVERY_RCVR_LOCK;

        if (!changed_speed_recovery)
            directed_speed_change = (current_speed != rc_agent_cfg_h.target_link_speed);
        else
            directed_speed_change = 1'b0;

        `uvm_info(name, $sformatf("ENTER Recovery.RcvrLock at %s, speed_change=%0d",
                                                              current_speed.name(), directed_speed_change), UVM_LOW)

        recovery_wait_ts(1'b0, "Recovery.RcvrLock", ok);
        if (ok) begin
            `uvm_info(name, "Recovery.RcvrLock COMPLETE - advancing to Recovery.RcvrCfg", UVM_LOW)
            next_recovery_substate = RECOVERY_RCVR_CFG;
            next_state = RECOVERY_ST;
        end
        else next_state = DETECT_ST;
    endtask : monitor_recovery_rcvr_lock

    task automatic monitor_recovery_rcvr_cfg(output recovery_substate_e next_recovery_substate,
                                                                                      output ltssm_state_e next_state);
        bit ok;
        current_recovery_substate = RECOVERY_RCVR_CFG;
        next_recovery_substate    = RECOVERY_RCVR_CFG;

        `uvm_info(name, $sformatf("ENTER Recovery.RcvrCfg at %s, speed_change=%0d",
                                                              current_speed.name(), directed_speed_change), UVM_LOW)

        recovery_wait_ts(1'b1, "Recovery.RcvrCfg", ok);
        if (!ok) begin next_state = DETECT_ST; return; end

        next_state = RECOVERY_ST;
        if (current_speed != rc_agent_cfg_h.target_link_speed) begin
            `uvm_info(name, "Recovery.RcvrCfg COMPLETE - another speed step needed -> Recovery.Speed", UVM_LOW)
            next_recovery_substate = RECOVERY_SPEED;
        end
        else if (current_speed >= EQ_REQUIRED_MIN_GEN && !equalization_done_this_speed) begin
            `uvm_info(name, "Recovery.RcvrCfg COMPLETE - target speed, equalization required -> Recovery.Equalization Phase 0", UVM_LOW)
            next_recovery_substate = RECOVERY_EQ_PHASE0;
        end
        else begin
            `uvm_info(name, "Recovery.RcvrCfg COMPLETE - advancing to Recovery.Idle", UVM_LOW)
            next_recovery_substate = RECOVERY_IDLE;
        end
    endtask : monitor_recovery_rcvr_cfg

    task automatic monitor_recovery_speed(output recovery_substate_e next_recovery_substate,
                                                                                output ltssm_state_e next_state);
        int unsigned seq_idx;
        bit          found_idx;
        current_recovery_substate = RECOVERY_SPEED;

        `uvm_info(name, $sformatf("ENTER Recovery.Speed (%s -> next step)", current_speed.name()), UVM_LOW)

        found_idx = 1'b0;
        for (int i = 0; i < $size(SPEED_UPGRADE_SEQUENCE); i++)
            if (SPEED_UPGRADE_SEQUENCE[i] == current_speed) begin seq_idx = i; found_idx = 1'b1; end
        if (found_idx && (seq_idx + 1) < $size(SPEED_UPGRADE_SEQUENCE))
            current_speed = SPEED_UPGRADE_SEQUENCE[seq_idx + 1];

        directed_speed_change        = 1'b0;
        changed_speed_recovery       = 1'b1;
        current_rate                 = current_speed;
        equalization_done_this_speed = 1'b0;
        symbol_lock_acquired         = 1'b0;
        if (current_speed == rc_agent_cfg_h.target_link_speed) successful_speed_negotiation = 1'b1;

        `uvm_info(name, $sformatf("Recovery.Speed COMPLETE - now at %s -> Recovery.RcvrLock", current_speed.name()), UVM_LOW)
        next_state             = RECOVERY_ST;
        next_recovery_substate = RECOVERY_RCVR_LOCK;
    endtask : monitor_recovery_speed

    // one task body for all four EQ phases, parameterised by phase
    task automatic recovery_eq_phase(input int phase,
                                                                      output recovery_substate_e next_recovery_substate,
                                                                      output ltssm_state_e next_state);
        modified_ts_bytes_t mod_rx;
        bit          mod_valid;
        bit [7:0]    exp_ec;
        int unsigned cnt;
        time         start_time;
        recovery_substate_e this_sub;
        recovery_substate_e nxt_sub;
        string       pname;

        case (phase)
            0: begin this_sub = RECOVERY_EQ_PHASE0; nxt_sub = RECOVERY_EQ_PHASE1; exp_ec = EC_PHASE0_1; pname = "Phase 0"; end
            1: begin this_sub = RECOVERY_EQ_PHASE1; nxt_sub = RECOVERY_EQ_PHASE2; exp_ec = EC_PHASE0_1; pname = "Phase 1"; end
            2: begin this_sub = RECOVERY_EQ_PHASE2; nxt_sub = RECOVERY_EQ_PHASE3; exp_ec = EC_PHASE2;   pname = "Phase 2"; end
            default: begin this_sub = RECOVERY_EQ_PHASE3; nxt_sub = RECOVERY_RCVR_LOCK; exp_ec = EC_PHASE3; pname = "Phase 3"; end
        endcase

        current_recovery_substate = this_sub;
        next_recovery_substate    = this_sub;
        `uvm_info(name, $sformatf("ENTER Recovery.Equalization %s", pname), UVM_LOW)

        cnt = 0;
        start_time = $time;
        forever begin
            monitor_receive_modified_ts(mod_rx, mod_valid);
            if (mod_valid && (mod_rx.id == MOD_TS1_ID || mod_rx.id == MOD_TS2_ID) &&
                    mod_rx.ec_byte == exp_ec && mod_rx.link_number == configured_link_number) begin
                cnt++;
                if (phase == 0) negotiated_tx_preset = mod_rx.payload;
            end
            else cnt = 0;

            if (cnt >= CONSEC_TS_COUNT) begin
                if (phase == 3) equalization_done_this_speed = 1'b1;
                `uvm_info(name, $sformatf("Recovery.Equalization %s COMPLETE -> %s", pname, nxt_sub.name()), UVM_LOW)
                next_state             = RECOVERY_ST;
                next_recovery_substate = nxt_sub;
                return;
            end
            if (($time - start_time) >= (RECOVERY_TIMEOUT_MS * 1ms)) begin
                `uvm_error(name, $sformatf("Recovery.Equalization %s Monitor Timeout - returning to Detect", pname))
                next_state = DETECT_ST;
                return;
            end
        end
    endtask : recovery_eq_phase

    task automatic monitor_recovery_eq_phase0(output recovery_substate_e next_recovery_substate, output ltssm_state_e next_state);
        recovery_eq_phase(0, next_recovery_substate, next_state);
    endtask : monitor_recovery_eq_phase0
    task automatic monitor_recovery_eq_phase1(output recovery_substate_e next_recovery_substate, output ltssm_state_e next_state);
        recovery_eq_phase(1, next_recovery_substate, next_state);
    endtask : monitor_recovery_eq_phase1
    task automatic monitor_recovery_eq_phase2(output recovery_substate_e next_recovery_substate, output ltssm_state_e next_state);
        recovery_eq_phase(2, next_recovery_substate, next_state);
    endtask : monitor_recovery_eq_phase2
    task automatic monitor_recovery_eq_phase3(output recovery_substate_e next_recovery_substate, output ltssm_state_e next_state);
        recovery_eq_phase(3, next_recovery_substate, next_state);
    endtask : monitor_recovery_eq_phase3

    task automatic monitor_recovery_idle(output recovery_substate_e next_recovery_substate,
                                                                              output ltssm_state_e next_state);
        bit [9:0] raw_symbol [0:PCIE_MAX_LANES-1];
        bit [7:0] rx_byte [0:PCIE_MAX_LANES-1];
        bit is_k [0:PCIE_MAX_LANES-1];
        bit code_err [0:PCIE_MAX_LANES-1];
        running_disparity_e matched_rd [0:PCIE_MAX_LANES-1];
        bit all_lanes_idle;
        int unsigned consec_idle_cnt;
        int unsigned idle_attempt_cnt;
        bit lock_found;
        bit [9:0] locked_code [0:PCIE_MAX_LANES-1];
        bit have_locked_symbols;

        current_recovery_substate = RECOVERY_IDLE;
        next_recovery_substate    = RECOVERY_IDLE;
        `uvm_info(name, "ENTER Recovery.Idle", UVM_LOW)

        consec_idle_cnt = 0;
        idle_attempt_cnt = 0;
        consec_invalid_rx_count = 0;
        symbol_lock_acquired = 1'b0;

        acquire_idle_symbol_lock(locked_code, lock_found);
        if (!lock_found) begin
            `uvm_error(name, "Recovery.Idle: IDLE lock failed - returning to Detect")
            next_state = DETECT_ST;
            return;
        end
        have_locked_symbols = 1'b1;

        forever begin
            all_lanes_idle = 1'b1;
            if (have_locked_symbols) begin
                for (int l = 0; l < get_active_lanes(); l++) begin
                    rx_byte[l] = decode_8b10b_symbol(locked_code[l], is_k[l], code_err[l], matched_rd[l]);
                    if (!code_err[l]) lane_disparity[l] = matched_rd[l];
                    if (code_err[l] || is_k[l] || rx_byte[l] != IDLE_SYMBOL) all_lanes_idle = 1'b0;
                end
                have_locked_symbols = 1'b0;
            end
            else begin
                sample_all_lanes_symbol_10b(raw_symbol);
                for (int l = 0; l < get_active_lanes(); l++) begin
                    rx_byte[l] = decode_8b10b_symbol(raw_symbol[l], is_k[l], code_err[l], matched_rd[l]);
                    if (!code_err[l]) lane_disparity[l] = matched_rd[l];
                    if (code_err[l] || is_k[l] || rx_byte[l] != IDLE_SYMBOL) all_lanes_idle = 1'b0;
                end
            end

            idle_attempt_cnt++;
            if (all_lanes_idle) consec_idle_cnt++; else consec_idle_cnt = 0;

            if (!all_lanes_idle) begin
                consec_invalid_rx_count++;
                if (consec_invalid_rx_count >= MAX_CONSEC_INVALID_RX) begin
                    consec_invalid_rx_count = 0;
                    acquire_idle_symbol_lock(locked_code, lock_found);
                    if (!lock_found) begin
                        `uvm_error(name, "Recovery.Idle: re-lock failed - returning to Detect")
                        next_state = DETECT_ST;
                        return;
                    end
                    have_locked_symbols = 1'b1;
                end
            end
            else consec_invalid_rx_count = 0;

            if (consec_idle_cnt >= MIN_IDLE_RX) begin
                `uvm_info(name, $sformatf("Recovery.Idle COMPLETE -> L0 after %0d IDLE symbols", consec_idle_cnt), UVM_LOW)
                next_state = L0_ST;
                return;
            end
            if (idle_attempt_cnt >= rc_agent_cfg_h.config_timeout_ts_count) begin
                `uvm_error(name, "Recovery.Idle Monitor Timeout - returning to Detect")
                next_state = DETECT_ST;
                return;
            end
        end
    endtask : monitor_recovery_idle


endinterface : pcie_phy_rc_monitor_bfm
`endif
