`ifndef PCIE_PHY_PKG_INCLUDED_
`define PCIE_PHY_PKG_INCLUDED_
 
package pcie_phy_pkg;
 
  //=========================================================================================
  // PARAMETERS
  //=========================================================================================
 
  //-------------------------------------------------------
  // Link / lane configuration
  //-------------------------------------------------------
  parameter int PCIE_MAX_LANES    = 16;  //Max lanes this AVIP is built to support
  parameter int ACTIVE_LANES      = 4;   //Active profile link width
  parameter int MAX_LINK_WIDTH_RC = 16;  //RC max supported width
  parameter int MAX_LINK_WIDTH_EP = 16;  //EP max supported width
  parameter int MAX_LINK_SPEED    = 6;   //Max Gen supported (GEN6)
  parameter int SYMBOL_WIDTH      = 8;
 
  //-------------------------------------------------------
  // Ordered-Set / Symbol length parameters (logical framing)
  //-------------------------------------------------------
  parameter int TS_OS_LENGTH  = 16;  //TS1/TS2: 1 COM + 15 data symbols
  parameter int SKP_OS_LENGTH = 4;   //SKIP: 1 COM + 3 SKP
  parameter int FTS_OS_LENGTH = 4;
  parameter int EIOS_LENGTH   = 4;
  parameter int EIEOS_LENGTH  = 16;
  parameter int SDS_OS_LENGTH = 16;
  parameter bit [7:0] N_FTS_DEFAULT = 8'h3C;
 
  //-------------------------------------------------------
  // LTSSM timeouts / counters
  //-------------------------------------------------------
  parameter int DETECT_TIMEOUT_MS   = 12;
  parameter int POLLING_TIMEOUT_MS  = 24;
  parameter int CONFIG_TIMEOUT_MS   = 2;
  parameter int RECOVERY_TIMEOUT_MS = 24;
 
  parameter int TIMEOUT_LINKWIDTH_MS = 24; //Config.Linkwidth.Start/Accept
  parameter int TIMEOUT_LANENUM_MS   = 2;  //Config.Lanenum.Wait/Accept
  parameter int TIMEOUT_COMPLETE_MS  = 2;  //Config.Complete
  parameter int TIMEOUT_IDLE_MS      = 2;  //Config.Idle
 
  parameter int TS1_1024_COUNT      = 1024; //Polling.Active: TS1 sent before falling
                                             //back to Polling.Compliance with no response
  parameter int CONSEC_TS_REQUIRED  = 2;    //Consecutive matching TS to advance most sub-states
  parameter int CONSEC_TS_COUNT     = 8;    //Consecutive matching TS/IDL required (generic)
  parameter int CONSEC_TS2_COMPLETE = 8;    //Consecutive TS2 rx required to exit Config.Complete
  parameter int MIN_TS2_TX_COMPLETE = 16;   //Min TS2 tx after first rx, to exit Config.Complete
  parameter int MIN_IDLE_TX         = 16;   //Min Idle symbols tx after first rx, to exit Config.Idle
  parameter int MIN_IDLE_RX         = 8;    //Min consecutive Idle symbols rx, to exit Config.Idle
  parameter int IDLE_COUNT          = 8;    //Generic idle-symbol threshold alias
 
  //-------------------------------------------------------
  // Logical symbol identifier values (symbol IDENTITY used for ordered-set/packet
  // formation and comparison; bit-level line encoding is Electrical Sub-block scope
  // and is not modeled here)
  //-------------------------------------------------------
  parameter bit [7:0] COM_SYMBOL   = 8'hBC; //Comma - OS start, resets scrambler LFSR
  parameter bit [7:0] PAD_SYMBOL   = 8'hF7; //Pad - unassigned Link#/Lane#
  parameter bit [7:0] TS1_ID_BYTE  = 8'h4A; //TS1 identifier symbol (D10.2)
  parameter bit [7:0] TS2_ID_BYTE  = 8'h45; //TS2 identifier symbol (D5.2)

  //-------------------------------------------------------
  // Modified TS1/TS2 (128b/130b, Gen3+) - identifier bytes and EC (Equalization Control)
  // field values. use_modified_ts becomes true once current_speed >= EQ_REQUIRED_MIN_GEN and
  // stays true from then on - it does not revert on a later speed step, since a link already
  // operating at Gen3+ never goes back to the standard 8b/10b TS format.
  //-------------------------------------------------------
  parameter bit [7:0] MOD_TS1_ID = 8'h1E;
  parameter bit [7:0] MOD_TS2_ID = 8'h2D;

  //EC field values - occupy bits[7:6] of byte 5 in the Modified TS format. EC=01b covers
  //BOTH Phase 0 (preset loading) and Phase 1 (FS/LF exchange) - the two phases share this
  //wire value and are distinguished by LTSSM-internal behavior, not by EC itself.
  parameter bit [7:0] EC_PHASE0_1 = 8'h40; //bits[7:6]=01
  parameter bit [7:0] EC_PHASE2   = 8'h80; //bits[7:6]=10
  parameter bit [7:0] EC_PHASE3   = 8'hC0; //bits[7:6]=11
  parameter bit [7:0] EC_DONE     = 8'h00; //bits[7:6]=00 - equalization complete

  parameter bit [7:0] IDLE_SYMBOL  = 8'h00; //Logical Idle data symbol (D0.0) - corrected
  parameter bit [7:0] EIE_SYM      = 8'hFC; //Electrical Idle Exit (logical marker)
  parameter bit [7:0] IDL_SYM      = 8'h7C; //Electrical Idle (K28.3) - EIOS content for
                                             //Recovery.Speed, distinct from EIE_SYM above
  parameter bit [7:0] SDS_SYM      = 8'hE1; //Start of Data Stream
  parameter bit [7:0] SKP_SYMBOL   = 8'hAA; //Skip
  parameter bit [7:0] FTS_ID       = 8'h55; //FTS identifier symbol
 
  //-------------------------------------------------------
  // NON_FLIT_MODE framing tokens - 128b/130b, GEN3-GEN5 only (logical framing)
  //-------------------------------------------------------
  parameter bit [7:0] STP_TOKEN = 8'hFB; //Start TLP
  parameter bit [7:0] SDP_TOKEN = 8'h5C; //Start DLLP
  parameter bit [7:0] END_TOKEN = 8'hFD; //End (good)
  parameter bit [7:0] EDB_TOKEN = 8'hFE; //End Bad
 
  
  //-------------------------------------------------------
  // FLIT_MODE parameters - fixed 256B Flit carrying Upper Layer TLP/DLLP content
  //-------------------------------------------------------
  parameter int FLIT_BYTES             = 256;
  parameter int FLIT_TLP_PAYLOAD_BYTES = 236;
  parameter int FLIT_DLP_BYTES         = 6;
  parameter int FLIT_CRC_BYTES         = 8;
  parameter int FLIT_FEC_BYTES         = 6;

  //Struct: flit_t
  //Referenced in comments alongside FLIT_MODE previously but never actually defined. Simple
  //flat layout: TLP payload + DLP (sequence number/ack fields, not broken out further here)
  //+ CRC + FEC, matching FLIT_TLP_PAYLOAD_BYTES/FLIT_DLP_BYTES/FLIT_CRC_BYTES/FLIT_FEC_BYTES
  //above (236+6+8+6 = 256 = FLIT_BYTES).
  typedef struct packed {
    logic [(FLIT_TLP_PAYLOAD_BYTES*8)-1:0] tlp_payload;
    logic [(FLIT_DLP_BYTES*8)-1:0]         dlp;
    logic [(FLIT_CRC_BYTES*8)-1:0]         crc;
    logic [(FLIT_FEC_BYTES*8)-1:0]         fec;
  } flit_t;

 
  //-------------------------------------------------------
  // Gen6 reference profile constants (x4 link, Gen6 capability advertised while
  // training at 2.5 GT/s). Example profile - override per test.
  //-------------------------------------------------------
  parameter bit [7:0] SYM4_GEN6 = 8'h3F; //Data Rate Id: FLIT+2.5/5/8/16/32 GT/s advertised
  parameter bit [7:0] SYM5_GEN6 = 8'h60; //Training Control: ELBC=11b, scrambling ON
  parameter bit [7:0] NTFS_RC   = 8'h84; //RC's N_FTS (Symbol 3)
  parameter bit [7:0] NTFS_EP   = 8'hC8; //EP's N_FTS (Symbol 3)
 
  //-------------------------------------------------------
  // Electrical Sub-block assumptions
  //-------------------------------------------------------
  parameter bit RX_DETECT_ASSUMED            = 1'b1; //Detect.Quiet->Detect.Active
  parameter bit PLL_LOCK_ASSUMED              = 1'b1; //Recovery.Speed rate change completes
  parameter bit ELECTRICAL_IDLE_EXIT_ASSUMED  = 1'b1; //driven off EIEOS, not voltage sensing
  parameter bit EQ_DONE_ASSUMED               = 1'b1; //analog EQ tuning assumed successful
 
  
  //=========================================================================================
  // ENUMS
  //=========================================================================================
 
  
  //Enum: port_type_e
  //Compact single-bit link-partner selector, used by RC/EP BFM tasks for pairwise checks
  typedef enum logic {
    PORT_RC = 1'b0,
    PORT_EP = 1'b1
  } port_type_e;
 
  //Enum: pcie_gen_e
  //Negotiated/advertised link speed (data rate)
  typedef enum logic [2:0] {
    GEN1 = 3'd0, //2.5  GT/s
    GEN2 = 3'd1, //5.0  GT/s
    GEN3 = 3'd2, //8.0  GT/s
    GEN4 = 3'd3, //16.0 GT/s
    GEN5 = 3'd4, //32.0 GT/s
    GEN6 = 3'd5  //64.0 GT/s - FLIT Mode mandatory, PAM4 (electrical, out of scope)
  } pcie_gen_e;
 
  //Type: speed_sequence_t / Parameter: SPEED_UPGRADE_SEQUENCE
  //Fixed step order the LTSSM walks through Recovery to reach GEN6 from GEN1.
  typedef pcie_gen_e speed_sequence_t [0:5];
  parameter speed_sequence_t SPEED_UPGRADE_SEQUENCE = '{GEN1, GEN2, GEN3, GEN4, GEN5, GEN6};

  //Parameter: FLIT_MODE_MANDATORY_FROM_GEN
  //Referenced in comments near data_transfer_mode_e for a while but never actually defined
  //until now. FLIT Mode is mandatory from GEN6 onward.
  parameter pcie_gen_e FLIT_MODE_MANDATORY_FROM_GEN = GEN6;

  //Parameter: EQ_REQUIRED_MIN_GEN
  //Minimum speed at which link equalization becomes a real, required part of Recovery.
  parameter pcie_gen_e EQ_REQUIRED_MIN_GEN = GEN3;
 
  //Enum: link_width_e
  //Negotiated link width
  typedef enum logic [5:0] {
    X1  = 6'd1,
    X2  = 6'd2,
    X4  = 6'd4,
    X8  = 6'd8,
    X12 = 6'd12,
    X16 = 6'd16,
    X32 = 6'd32
  } link_width_e;
 
  //Enum: ltssm_state_e
  //Top level LTSSM states
  typedef enum logic [3:0] {
    DETECT_ST    = 4'h0,
    POLLING_ST   = 4'h1,
    CONFIG_ST    = 4'h2,
    L0_ST        = 4'h3,
    RECOVERY_ST  = 4'h4,
    LOOPBACK_ST  = 4'h5,
    DISABLED_ST  = 4'h6,
    HOT_RESET_ST = 4'h7,
    L0s_ST       = 4'h8,
    L1_ST        = 4'h9,
    L2_ST        = 4'hA
  } ltssm_state_e;
 
  //-------------------------------------------------------
  // Per-state sub-state enums.
  // One enum per row of ltssm_state_e that actually HAS sub-states. DISABLED_ST,
  // HOT_RESET_ST and L0_ST are intentionally absent here - they are single,
  // un-broken-down states; there is nothing to enumerate under them.
  // All are sized to 3 bits so they share one packed union below (ltssm_substate_u).
  //-------------------------------------------------------
 
  //Enum: detect_substate_e - sub-states of ltssm_state_e::DETECT_ST
  typedef enum logic [2:0] {
    DETECT_QUIET,
    DETECT_ACTIVE
  } detect_substate_e;
 
  //Enum: polling_substate_e - sub-states of ltssm_state_e::POLLING_ST
  typedef enum logic [2:0] {
    POLLING_ACTIVE,
    POLLING_CONFIG,
    POLLING_COMPLIANCE
  } polling_substate_e;
 
  //Enum: config_substate_e - sub-states of ltssm_state_e::CONFIG_ST
  typedef enum logic [2:0] {
    CFG_LINKWIDTH_START,
    CFG_LINKWIDTH_ACCEPT,
    CFG_LANENUM_WAIT,
    CFG_LANENUM_ACCEPT,
    CFG_COMPLETE,
    CFG_IDLE
  } config_substate_e;
 
  //Enum: recovery_substate_e - sub-states of ltssm_state_e::RECOVERY_ST
  //RECOVERY_RCVR_LOCK/RECOVERY_SPEED/RECOVERY_RCVR_CFG/RECOVERY_IDLE are re-entered once per
  //step of SPEED_UPGRADE_SEQUENCE when stepping up to GEN6. The single RECOVERY_EQUALIZATION
  //placeholder is replaced with the 4 real phases (EC=01b/01b/10b/11b per spec) - EC=01b
  //covers both Phase 0 and Phase 1, distinguished behaviourally, not by wire value; see
  //run_recovery_eq_phase0()/phase1()'s own headers.
  typedef enum logic [2:0] {
    RECOVERY_RCVR_LOCK,
    RECOVERY_RCVR_CFG,
    RECOVERY_SPEED,
    RECOVERY_EQ_PHASE0,
    RECOVERY_EQ_PHASE1,
    RECOVERY_EQ_PHASE2,
    RECOVERY_EQ_PHASE3,
    RECOVERY_IDLE
  } recovery_substate_e;
 
  //Enum: loopback_substate_e - sub-states of ltssm_state_e::LOOPBACK_ST
  typedef enum logic [2:0] {
    LOOPBACK_ENTRY,
    LOOPBACK_ACTIVE,
    LOOPBACK_EXIT
  } loopback_substate_e;
 
  //Enum: l0s_substate_e - sub-states of ltssm_state_e::L0s_ST
  typedef enum logic [2:0] {
    TX_L0S_ENTRY,
    TX_L0S_IDLE,
    TX_L0S_FTS,
    RX_L0S_ENTRY,
    RX_L0S_IDLE,
    RX_L0S_FTS
  } l0s_substate_e;
 
  
 
 
  //Enum: ltssm_next_action_e
  //Exit/next-state decision returned by each run_* sub-state task
  typedef enum logic [3:0] {
    NEXT_NONE         = 4'd0, //advance to the next sub-state in normal sequence
    NEXT_COMPLETE     = 4'd1,
    NEXT_LANENUM_WAIT = 4'd2,
    NEXT_DETECT       = 4'd3, //timeout / link-down -> back to Detect
    NEXT_L0           = 4'd4,
    NEXT_DISABLED     = 4'd5,
    NEXT_LOOPBACK     = 4'd6,
    NEXT_HOT_RESET    = 4'd7,
    NEXT_RECOVERY     = 4'd8  //speed-change request, or any in-L0 trigger to retrain
  } ltssm_next_action_e;
 
  //Enum: os_type_e
  //Ordered-Sets exchanged during link init/training/speed-change
  typedef enum logic [3:0] {
    OS_NONE,
    OS_TS1,
    OS_TS2,
    OS_MODIFIED_TS,               //Modified TS1/TS2 format (once use_modified_ts1_ts2 latches)
    OS_SKIP,
    OS_EIOS,
    OS_EIEOS,
    OS_FTS,
    OS_SDS,
    OS_COMPLIANCE,
    OS_MODIFIED_COMPLIANCE,
    OS_IDLE
  } os_type_e;
 

  //Enum: eq_phase_e
  //GEN3+ Transmitter Equalization phases performed during Recovery.Equalization
  typedef enum logic [1:0] {
    EQ_PHASE0,
    EQ_PHASE1,
    EQ_PHASE2,
    EQ_PHASE3
  } eq_phase_e;
 
    //Enum: pipe_rate_e
  //Logical rate REQUEST value driven on the PIPE interface
  typedef enum logic [3:0] {
    PIPE_RATE_GEN1 = 4'h0,
    PIPE_RATE_GEN2 = 4'h1,
    PIPE_RATE_GEN3 = 4'h2,
    PIPE_RATE_GEN4 = 4'h3,
    PIPE_RATE_GEN5 = 4'h4,
    PIPE_RATE_GEN6 = 4'h5
  } pipe_rate_e;

  //Enum: bfm_verify_task_e
  //Test/debug-only - selects exactly which driver_bfm task a verification sequence wants
  //exercised next. Has no protocol meaning; it exists purely so every task implemented in
  //rc_driver_bfm/ep_driver_bfm can be called at least once from a directed sequence, in
  //whatever order, without needing real LTSSM stimulus to reach that state naturally.
  typedef enum {
    VERIFY_SEND_TS1,                    //drive_ts(OS_TS1, ...)          - rc + ep
    VERIFY_SEND_TS2,                    //drive_ts(OS_TS2, ...)          - rc + ep
    VERIFY_SEND_IDLE,                   //drive_idle()                   - rc + ep
    VERIFY_CHECK_ELECTRICAL_IDLE_EXIT,  //check_electrical_idle_exit_any_lane() - ep only
    VERIFY_PERFORM_RECEIVER_DETECTION,  //perform_receiver_detection_all_lanes() - ep only
    VERIFY_RUN_DETECT_QUIET,            //run_detect_quiet(...)          - ep only
    VERIFY_RUN_DETECT_ACTIVE,            //run_detect_active(...)         - ep only
    VERIFY_RUN_POLLING,
    VERIFY_RUN_CONFIG_LINKWIDTH_START,
    VERIFY_RUN_CONFIG_LINKWIDTH_ACCEPT,
    VERIFY_RUN_CONFIG_LANENUM_WAIT
} bfm_verify_task_e;

  //Struct: ltssm_status_t
  //Compact BFM->observer status word: current shadow LTSSM state plus a link-up flag.
  //Driven by driver_bfm/monitor_bfm as an output port for scoreboard/monitor visibility.
  typedef struct packed {
    ltssm_state_e state;
    logic         link_up;
  } ltssm_status_t;

  //Struct: pcie_phy_bfm_cfg_s
  //BFM-side config struct used by rc_cfg_converter / ep_cfg_converter to pack
  //agent_config fields (rate/lane capability) down to the pin-level driver_bfm.
  typedef struct packed {
    bit [6:0] supported_rates;
    bit       flit_mode_supported;
    bit [4:0] active_lanes;
  } pcie_phy_bfm_cfg_s;
 
  
  //Enum: other_condition_e
  //Miscellaneous per-lane link conditions tracked during training
  typedef enum logic [1:0] {
    LINK_UP,
    UP_CONFIGURE,
    WIDTH_CHANGE
  } other_condition_e;
 
  //Enum: encoding_type_e
  //Line-coding scheme in effect at the negotiated speed (informational - actual bit-level
  //coding is Electrical/PCS scope, this just tags which framing rules apply)
  typedef enum logic [1:0] {
    ENC_8B10B,    //GEN1-GEN2
    ENC_128B130B, //GEN3-GEN5, NON_FLIT_MODE
    ENC_FLIT      //FLIT_MODE (mandatory GEN6, optional GEN1-GEN5 if negotiated)
  } encoding_type_e;
 
  //Enum: data_transfer_mode_e
  //Which framing scheme actual data transfer uses once L0 is reached.
  //Always FLIT_MODE at GEN6 (see FLIT_MODE_MANDATORY_FROM_GEN); may be either at GEN1-GEN5.
  typedef enum logic {
    NON_FLIT_MODE = 1'b0, //Legacy STP/SDP/END/EDB framed TLPs/DLLPs
    FLIT_MODE     = 1'b1  //Fixed 256B Flits (flit_t)
  } data_transfer_mode_e;
 
  //Enum: flit_content_e
  //What a Flit currently carries (FLIT_MODE only)
  typedef enum logic [1:0] {
    LOGICAL_IDLE_FLIT,  //No Upper Layer data available
    DATA_FLIT,          //Carries TLP/DLLP content from the Upper Layer
    SKP_ORDERED_SET     //Periodic Flit-mode SKP Ordered Set (clock compensation)
  } flit_content_e;
 
  //=========================================================================================
  // STRUCTS  (all `packed` so every type here can be driven/sampled directly on an
  //           interface or cast to/from a bit-vector)
  //=========================================================================================
 
  //Struct: ts_ordered_set_t
  //Decoded TS1/TS2 Ordered-Set fields used for Link Initialization/Training and
  //speed-negotiation packet formation, common to RC and EP
  typedef struct packed {
    os_type_e  os_type;
    logic [7:0] link_number;
    logic [7:0] lane_number;
    logic [7:0] n_fts;
    pcie_gen_e data_rate;
    logic      speed_change;         //Symbol4 Bit7 - requests entry into Recovery.Speed
    logic      autonomous_change;
    logic      disable_scrambling;
    logic      loopback;
    logic      disable_link;
    logic      hot_reset;
    logic      select_deemphasis;
    logic      compliance_receive;
    logic      flit_mode_supported;  //Symbol4 Bit0 - negotiates FLIT_MODE
    logic [3:0] tx_preset;
    logic [2:0] rx_preset_hint;
  } ts_ordered_set_t;
 
  //Struct: ts_ordered_set_bytes_t
  //Raw wire-level TS1/TS2 Ordered Set, symbol by symbol - used to build/compare the exact
  //byte pattern driven/received on each lane (packed 2D array - all-packed, safe to embed)
  typedef struct packed {
    logic [7:0] sym0_com;
    logic [7:0] sym1_link_number;
    logic [7:0] sym2_lane_number;
    logic [7:0] sym3_n_fts;
    logic [7:0] sym4_data_rate_id;
    logic [7:0] sym5_training_ctrl;
    logic [9:0][7:0] sym6_15_identifier; //packed 10x8b: TS1_ID_BYTE x10 or TS2_ID_BYTE x10
  } ts_ordered_set_bytes_t;
 
  //Struct: modified_ts_bytes_t
  //Modified TS1/TS2 (128b/130b, Gen3+) logical content - only the 7 real content bytes
  //(0-6). Byte 7 (parity), bytes 8-14 (replica of 0-6), and byte 15 (parity of the replica)
  //are all DERIVED from these 7 at drive time and independently reconstructed/checked at
  //receive time - not stored here, same separation of concerns as ts_ordered_set_bytes_t
  //versus its own serialization in drive_ts()/receive_ts().
  typedef struct packed {
    logic [7:0] id;           //byte0: MOD_TS1_ID or MOD_TS2_ID
    logic [7:0] link_number;  //byte1
    logic [7:0] lane_number;  //byte2
    logic [7:0] n_fts;        //byte3
    logic [7:0] data_rate_id; //byte4 - bit7 is still speed_change (SC), same position as
                               //the standard format
    logic [7:0] ec_byte;      //byte5 - bits[7:6] = EC (EC_PHASE0_1/EC_PHASE2/EC_PHASE3/
                               //EC_DONE); this REPLACES byte5's meaning from the standard
                               //format (which carried ELBC/scramble/hot_reset etc there) -
                               //Modified TS byte5 is EC only, not the same bit layout
    logic [7:0] payload;      //byte6 - meaning depends on phase: EQ preset (Phase 0),
                               //FS/LF info (Phase 1), coefficient request/status (Phase 2/3),
                               //or Gen6 capabilities (post-EQ, EC=EC_DONE)
  } modified_ts_bytes_t;
 
  //Struct: sym4_data_rate_t
  //Bit-field breakdown of Symbol 4 (Data Rate Identifier)
  typedef struct packed {
    logic speed_change;        //Bit7
    logic autonomous_change;   //Bit6
    logic speed_32gts;         //Bit5
    logic speed_16gts;         //Bit4
    logic speed_8gts;          //Bit3
    logic speed_5gts;          //Bit2
    logic speed_2p5gts;        //Bit1
    logic flit_mode_supported; //Bit0
  } sym4_data_rate_t;
 
  //Struct: sym5_training_ctrl_t
  //Bit-field breakdown of Symbol 5 (Training Control)
  typedef struct packed {
    logic reserved_7;
    logic elbc_hi;        //Bit6 - ELBC[1]
    logic elbc_lo;        //Bit5 - ELBC[0]
    logic no_scrambling;  //Bit4
    logic reserved_3;
    logic loopback;       //Bit2
    logic disable_link;   //Bit1
    logic hot_reset;      //Bit0
  } sym5_training_ctrl_t;
 
  //Struct: speed_cap_t
  //Advertised speed/FLIT capability bits (from Symbol4 across TS1/TS2 exchange)
  typedef struct packed {
    logic gen1_support;
    logic gen2_support;
    logic gen3_support;
    logic gen4_support;
    logic gen5_support;
    logic gen6_support;
    logic flit_support;
  } speed_cap_t;
 
  //Struct: speed_change_t
  //Minimal speed-change handshake state for one Recovery pass
  typedef struct packed {
    pcie_gen_e current_speed;
    pcie_gen_e target_speed;
    logic      start_change;
    logic      speed_done;
  } speed_change_t;
 
 
  typedef enum bit {
    RD_MINUS = 1'b0, //more 0s than 1s sent so far (or balanced) - next control/data symbol
                      //uses the RD- encoding
    RD_PLUS  = 1'b1  //more 1s than 0s sent so far - next symbol uses the RD+ encoding
  } running_disparity_e;
 
  //-------------------------------------------------------
  // K-code (control character) encoded pairs - only these 8 symbols get a special-case
  //-------------------------------------------------------
  parameter bit [9:0] K_COM_P = 10'b1100000101;
  parameter bit [9:0] K_COM_N = 10'b0011111010;
  parameter bit [9:0] K_PAD_P = 10'b0001010111;
  parameter bit [9:0] K_PAD_N = 10'b1110101000;
  parameter bit [9:0] K_SKP_P = 10'b1100001011;
  parameter bit [9:0] K_SKP_N = 10'b0011110100;
  parameter bit [9:0] K_STP_P = 10'b0010010111;
  parameter bit [9:0] K_STP_N = 10'b1101101000;
  parameter bit [9:0] K_SDP_P = 10'b1100001010;
  parameter bit [9:0] K_SDP_N = 10'b0011110101;
  parameter bit [9:0] K_END_P = 10'b0100010111;
  parameter bit [9:0] K_END_N = 10'b1011101000;
  parameter bit [9:0] K_EDB_P = 10'b1000010111;
  parameter bit [9:0] K_EDB_N = 10'b0111101000;
  parameter bit [9:0] K_EIE_P = 10'b1100000111;
  parameter bit [9:0] K_EIE_N = 10'b0011111000;
  parameter bit [9:0] K_IDL_P = 10'b1100001100; //K28.3, standard table
  parameter bit [9:0] K_IDL_N = 10'b0011110011;
 
  //-------------------------------------------------------
  // Generic D-code (data character) tables, indexed by the 8-bit byte value (0-255).
  // D_NEG_DISP[byte] = 10b encoding to use when current disparity is RD_MINUS.
  // D_POS_DISP[byte] = 10b encoding to use when current disparity is RD_PLUS.
  //-------------------------------------------------------
  parameter bit [9:0] D_NEG_DISP [0:255] = '{
    10'b1001110100, 10'b0111010100, 10'b1011010100, 10'b1100011011, 10'b1101010100, 10'b1010011011, 10'b0110011011, 10'b1110001011,
    10'b1110010100, 10'b1001011011, 10'b0101011011, 10'b1101001011, 10'b0011011011, 10'b1011001011, 10'b0111001011, 10'b0101110100,
    10'b0110110100, 10'b1000111011, 10'b0100111011, 10'b1100101011, 10'b0010111011, 10'b1010101011, 10'b0110101011, 10'b1110100100,
    10'b1100110100, 10'b1001101011, 10'b0101101011, 10'b1101100100, 10'b0011101011, 10'b1011100100, 10'b0111100100, 10'b1010110100,
    10'b1001111001, 10'b0111011001, 10'b1011011001, 10'b1100011001, 10'b1101011001, 10'b1010011001, 10'b0110011001, 10'b1110001001,
    10'b1110011001, 10'b1001011001, 10'b0101011001, 10'b1101001001, 10'b0011011001, 10'b1011001001, 10'b0111001001, 10'b0101111001,
    10'b0110111001, 10'b1000111001, 10'b0100111001, 10'b1100101001, 10'b0010111001, 10'b1010101001, 10'b0110101001, 10'b1110101001,
    10'b1100111001, 10'b1001101001, 10'b0101101001, 10'b1101101001, 10'b0011101001, 10'b1011101001, 10'b0111101001, 10'b1010111001,
    10'b1001110101, 10'b0111010101, 10'b1011010101, 10'b1100010101, 10'b1101010101, 10'b1010010101, 10'b0110010101, 10'b1110000101,
    10'b1110010101, 10'b1001010101, 10'b0101010101, 10'b1101000101, 10'b0011010101, 10'b1011000101, 10'b0111000101, 10'b0101110101,
    10'b0110110101, 10'b1000110101, 10'b0100110101, 10'b1100100101, 10'b0010110101, 10'b1010100101, 10'b0110100101, 10'b1110100101,
    10'b1100110101, 10'b1001100101, 10'b0101100101, 10'b1101100101, 10'b0011100101, 10'b1011100101, 10'b0111100101, 10'b1010110101,
    10'b1001110011, 10'b0111010011, 10'b1011010011, 10'b1100011100, 10'b1101010011, 10'b1010011100, 10'b0110011100, 10'b1110001100,
    10'b1110010011, 10'b1001011100, 10'b0101011100, 10'b1101001100, 10'b0011011100, 10'b1011001100, 10'b0111001100, 10'b0101110011,
    10'b0110110011, 10'b1000111100, 10'b0100111100, 10'b1100101100, 10'b0010111100, 10'b1010101100, 10'b0110101100, 10'b1110100011,
    10'b1100110011, 10'b1001101100, 10'b0101101100, 10'b1101100011, 10'b0011101100, 10'b1011100011, 10'b0111100011, 10'b1010110011,
    10'b1001110010, 10'b0111010010, 10'b1011010010, 10'b1100011101, 10'b1101010010, 10'b1010011101, 10'b0110011101, 10'b1110001101,
    10'b1110010010, 10'b1001011101, 10'b0101011101, 10'b1101001101, 10'b0011011101, 10'b1011001101, 10'b0111001101, 10'b0101110010,
    10'b0110110010, 10'b1000111101, 10'b0100111101, 10'b1100101101, 10'b0010111101, 10'b1010101101, 10'b0110101101, 10'b1110100010,
    10'b1100110010, 10'b1001101101, 10'b0101101101, 10'b1101100010, 10'b0011101101, 10'b1011100010, 10'b0111100010, 10'b1010110010,
    10'b1001111010, 10'b0111011010, 10'b1011011010, 10'b1100011010, 10'b1101011010, 10'b1010011010, 10'b0110011010, 10'b1110001010,
    10'b1110011010, 10'b1001011010, 10'b0101011010, 10'b1101001010, 10'b0011011010, 10'b1011001010, 10'b0111001010, 10'b0101111010,
    10'b0110111010, 10'b1000111010, 10'b0100111010, 10'b1100101010, 10'b0010111010, 10'b1010101010, 10'b0110101010, 10'b1110101010,
    10'b1100111010, 10'b1001101010, 10'b0101101010, 10'b1101101010, 10'b0011101010, 10'b1011101010, 10'b0111101010, 10'b1010111010,
    10'b1001110110, 10'b0111010110, 10'b1011010110, 10'b1100010110, 10'b1101010110, 10'b1010010110, 10'b0110010110, 10'b1110000110,
    10'b1110010110, 10'b1001010110, 10'b0101010110, 10'b1101000110, 10'b0011010110, 10'b1011000110, 10'b0111000110, 10'b0101110110,
    10'b0110110110, 10'b1000110110, 10'b0100110110, 10'b1100100110, 10'b0010110110, 10'b1010100110, 10'b0110100110, 10'b1110100110,
    10'b1100110110, 10'b1001100110, 10'b0101100110, 10'b1101100110, 10'b0011100110, 10'b1011100110, 10'b0111100110, 10'b1010110110,
    10'b1001110001, 10'b0111010001, 10'b1011010001, 10'b1100011110, 10'b1101010001, 10'b1010011110, 10'b0110011110, 10'b1110001110,
    10'b1110010001, 10'b1001011110, 10'b0101011110, 10'b1101001110, 10'b0011011110, 10'b1011001110, 10'b0111001110, 10'b0101110001,
    10'b0110110001, 10'b1000110111, 10'b0100110111, 10'b1100101110, 10'b0010110111, 10'b1010101110, 10'b0110101110, 10'b1110100001,
    10'b1100110001, 10'b1001101110, 10'b0101101110, 10'b1101100001, 10'b0011101110, 10'b1011100001, 10'b0111100001, 10'b1010110001
  };
 
  parameter bit [9:0] D_POS_DISP [0:255] = '{
    10'b0110001011, 10'b1000101011, 10'b0100101011, 10'b1100010100, 10'b0010101011, 10'b1010010100, 10'b0110010100, 10'b0001110100,
    10'b0001101011, 10'b1001010100, 10'b0101010100, 10'b1101000100, 10'b0011010100, 10'b1011000100, 10'b0111000100, 10'b1010001011,
    10'b1001001011, 10'b1000110100, 10'b0100110100, 10'b1100100100, 10'b0010110100, 10'b1010100100, 10'b0110100100, 10'b0001011011,
    10'b0011001011, 10'b1001100100, 10'b0101100100, 10'b0010011011, 10'b0011100100, 10'b0100011011, 10'b1000011011, 10'b0101001011,
    10'b0110001001, 10'b1000101001, 10'b0100101001, 10'b1100011001, 10'b0010101001, 10'b1010011001, 10'b0110011001, 10'b0001111001,
    10'b0001101001, 10'b1001011001, 10'b0101011001, 10'b1101001001, 10'b0011011001, 10'b1011001001, 10'b0111001001, 10'b1010001001,
    10'b1001001001, 10'b1000111001, 10'b0100111001, 10'b1100101001, 10'b0010111001, 10'b1010101001, 10'b0110101001, 10'b0001011001,
    10'b0011001001, 10'b1001101001, 10'b0101101001, 10'b0010011001, 10'b0011101001, 10'b0100011001, 10'b1000011001, 10'b0101001001,
    10'b0110000101, 10'b1000100101, 10'b0100100101, 10'b1100010101, 10'b0010100101, 10'b1010010101, 10'b0110010101, 10'b0001110101,
    10'b0001100101, 10'b1001010101, 10'b0101010101, 10'b1101000101, 10'b0011010101, 10'b1011000101, 10'b0111000101, 10'b1010000101,
    10'b1001000101, 10'b1000110101, 10'b0100110101, 10'b1100100101, 10'b0010110101, 10'b1010100101, 10'b0110100101, 10'b0001010101,
    10'b0011000101, 10'b1001100101, 10'b0101100101, 10'b0010010101, 10'b0011100101, 10'b0100010101, 10'b1000010101, 10'b0101000101,
    10'b0110001100, 10'b1000101100, 10'b0100101100, 10'b1100010011, 10'b0010101100, 10'b1010010011, 10'b0110010011, 10'b0001110011,
    10'b0001101100, 10'b1001010011, 10'b0101010011, 10'b1101000011, 10'b0011010011, 10'b1011000011, 10'b0111000011, 10'b1010001100,
    10'b1001001100, 10'b1000110011, 10'b0100110011, 10'b1100100011, 10'b0010110011, 10'b1010100011, 10'b0110100011, 10'b0001011100,
    10'b0011001100, 10'b1001100011, 10'b0101100011, 10'b0010011100, 10'b0011100011, 10'b0100011100, 10'b1000011100, 10'b0101001100,
    10'b0110001101, 10'b1000101101, 10'b0100101101, 10'b1100010010, 10'b0010101101, 10'b1010010010, 10'b0110010010, 10'b0001110010,
    10'b0001101101, 10'b1001010010, 10'b0101010010, 10'b1101000010, 10'b0011010010, 10'b1011000010, 10'b0111000010, 10'b1010001101,
    10'b1001001101, 10'b1000110010, 10'b0100110010, 10'b1100100010, 10'b0010110010, 10'b1010100010, 10'b0110100010, 10'b0001011101,
    10'b0011001101, 10'b1001100010, 10'b0101100010, 10'b0010011101, 10'b0011100010, 10'b0100011101, 10'b1000011101, 10'b0101001101,
    10'b0110001010, 10'b1000101010, 10'b0100101010, 10'b1100011010, 10'b0010101010, 10'b1010011010, 10'b0110011010, 10'b0001111010,
    10'b0001101010, 10'b1001011010, 10'b0101011010, 10'b1101001010, 10'b0011011010, 10'b1011001010, 10'b0111001010, 10'b1010001010,
    10'b1001001010, 10'b1000111010, 10'b0100111010, 10'b1100101010, 10'b0010111010, 10'b1010101010, 10'b0110101010, 10'b0001011010,
    10'b0011001010, 10'b1001101010, 10'b0101101010, 10'b0010011010, 10'b0011101010, 10'b0100011010, 10'b1000011010, 10'b0101001010,
    10'b0110000110, 10'b1000100110, 10'b0100100110, 10'b1100010110, 10'b0010100110, 10'b1010010110, 10'b0110010110, 10'b0001110110,
    10'b0001100110, 10'b1001010110, 10'b0101010110, 10'b1101000110, 10'b0011010110, 10'b1011000110, 10'b0111000110, 10'b1010000110,
    10'b1001000110, 10'b1000110110, 10'b0100110110, 10'b1100100110, 10'b0010110110, 10'b1010100110, 10'b0110100110, 10'b0001010110,
    10'b0011000110, 10'b1001100110, 10'b0101100110, 10'b0010010110, 10'b0011100110, 10'b0100010110, 10'b1000010110, 10'b0101000110,
    10'b0110001110, 10'b1000101110, 10'b0100101110, 10'b1100010001, 10'b0010101110, 10'b1010010001, 10'b0110010001, 10'b0001110001,
    10'b0001101110, 10'b1001010001, 10'b0101010001, 10'b1101001000, 10'b0011010001, 10'b1011001000, 10'b0111001000, 10'b1010001110,
    10'b1001001110, 10'b1000110001, 10'b0100110001, 10'b1100100001, 10'b0010110001, 10'b1010100001, 10'b0110100001, 10'b0001011110,
    10'b0011001110, 10'b1001100001, 10'b0101100001, 10'b0010011110, 10'b0011100001, 10'b0100011110, 10'b1000011110, 10'b0101001110
  };
 
  //-------------------------------------------------------
  // Enum: pcie_phy_ltssm_task_e
  // REAL protocol dispatch selector - distinct from bfm_verify_task_e (which is debug-only
  // and has no protocol meaning). One value = exactly one callable task in
  // rc_driver_bfm/ep_driver_bfm. A per-state sequence sets exactly one of these; the
  // driver_proxy's job is only to call the matching task and copy its real output arguments
  // back onto the item - it never decides what runs next.
  //-------------------------------------------------------
  typedef enum {
    LTSSM_TASK_DETECT_QUIET,
    LTSSM_TASK_DETECT_ACTIVE,
    LTSSM_TASK_POLLING_ACTIVE,
    LTSSM_TASK_POLLING_COMPLIANCE,
    LTSSM_TASK_POLLING_CONFIGURATION,
    LTSSM_TASK_CFG_LINKWIDTH_START,
    LTSSM_TASK_CFG_LINKWIDTH_ACCEPT,
    LTSSM_TASK_CFG_LANENUM_WAIT,
    LTSSM_TASK_CFG_LANENUM_ACCEPT,
    LTSSM_TASK_CFG_COMPLETE,
    LTSSM_TASK_CFG_IDLE,
    LTSSM_TASK_L0
  } pcie_phy_ltssm_task_e;

  //-------------------------------------------------------
  // Variable: exit_compliance_req
  // Package-scope, mirroring the reference PCIe_MONITOR model's cur_speed pattern. NOT set by
  // the monitor - a test/sequence-level control knob: set to 1 externally to request leaving
  // Polling.Compliance (which otherwise has no logical exit condition of its own per spec).
  // run_polling_compliance() checks it every loop iteration and clears it back to 0 once
  // consumed.
  //-------------------------------------------------------
  bit exit_compliance_req;

  //-------------------------------------------------------
  // Variable: recovery_request
  // Same pattern as exit_compliance_req. A test/sequence sets this to 1 externally to force
  // L0 -> Recovery (directed retrain). run_l0() checks it every loop iteration and clears it
  // back to 0 once consumed.
  //-------------------------------------------------------
  bit recovery_request;

  //-------------------------------------------------------
  // Cross-side transition barrier flags (Configuration substates)
  //
  // Root cause this fixes: each side's task previously tore down its own TX thread
  // (disable fork) the instant ITS OWN local exit condition was met, with no regard for
  // whether the partner had finished receiving against the OLD content yet. Since the two
  // sides' exit conditions are not equally hard to satisfy (e.g. EP's Linkwidth.Start check
  // is structurally easier than RC's), one side would routinely finish and move to
  // completely different content while the other was still deep in its own receive loop -
  // corrupting that side's symbol lock with no way to recover, since the content it was
  // chasing had genuinely stopped being sent.
  //
  // Fix: each side sets its OWN flag once its local condition is met, then blocks on the
  // PARTNER's flag before disabling its TX fork - keeping the SAME content flowing the
  // whole time it waits. This bounds the handoff skew to roughly one TS-reception-cycle
  // instead of an unbounded amount, and both sides remain on compatible content throughout.
  //
  // Named per-substate (not a single generic counter) because retry loops - e.g.
  // Lanenum.Accept looping back to Lanenum.Wait on a smaller-link renegotiation - mean the
  // two sides do not always take the same number of steps, so a shared monotonic counter
  // would not stay meaningfully aligned across a retry.
  //
  // IMPORTANT - flags are set but deliberately NEVER cleared after use (originally they
  // were cleared immediately after the wait unblocked - that had a genuine race: if side A
  // reaches its condition first, sets its flag, and starts waiting, side B may reach its own
  // condition, see A's flag, succeed, and clear ITS OWN flag again almost instantly - all
  // within a single clock edge on B's side. If A's own poll (running on A's independent
  // clock edges) hadn't yet checked during that exact window, A could miss ever seeing B's
  // flag true at all, and time out despite B having genuinely succeeded. Confirmed directly:
  // RC completed successfully while EP's identical wait for RC's flag timed out, in the same
  // run, on the same barrier. Since none of these states are re-entered within a single
  // successful training run (only a full default_values() reset would revisit them), leaving
  // the flags set once used is safe and removes the race entirely - whichever side sets its
  // flag first, it simply stays visible for the other to find, no matter how much later.
  //-------------------------------------------------------
  //Polling.Configuration also needs this barrier - it's the same class of race as the
  //Configuration substates below, just one boundary earlier. Confirmed by direct evidence:
  //EP finished and moved to Configuration.Linkwidth while RC was still deep in its own
  //Polling.Configuration receive loop, and RC never recovered for the rest of its timeout
  //window - the self-healing watchdog alone wasn't enough here because the content EP was
  //now sending genuinely didn't match what RC's still-active task was looking for.
  bit rc_ready_polling_config;
  bit ep_ready_polling_config;

  bit rc_ready_linkwidth_start;
  bit ep_ready_linkwidth_start;
  bit rc_ready_linkwidth_accept;
  bit ep_ready_linkwidth_accept;
  bit rc_ready_lanenum_wait;
  bit ep_ready_lanenum_wait;
  bit rc_ready_lanenum_accept;
  bit ep_ready_lanenum_accept;
  bit rc_ready_complete;
  bit ep_ready_complete;
  bit rc_ready_idle;
  bit ep_ready_idle;

  //Enum: recovery_reason_e
  //Published by run_l0() alongside next_state=RECOVERY_ST so the caller (and any log/coverage
  //consumer) knows WHY Recovery was entered - real PCIe hardware distinguishes these too, not
  //just "we're in Recovery."
  typedef enum {
    RECOVERY_REASON_NONE,
    RECOVERY_REASON_SPEED_CHANGE,     //current_speed != target_link_speed
    RECOVERY_REASON_DIRECTED,         //recovery_request flag set externally
    RECOVERY_REASON_ERROR_THRESHOLD,  //too many consecutive receive errors in L0
    RECOVERY_REASON_IDLE_TIMEOUT,     //no legitimate Idle seen from partner for too long
    RECOVERY_REASON_PARTNER_INITIATED //saw a qualified real TS1 arrive while still in L0 -
                                       //the partner already left L0 on its own, so we follow
  } recovery_reason_e;

endpackage : pcie_phy_pkg
 
`endif
