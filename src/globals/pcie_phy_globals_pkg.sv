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
  parameter bit [7:0] IDLE_SYMBOL  = 8'h00; //Logical Idle data symbol (D0.0) - corrected
  parameter bit [7:0] EIE_SYM      = 8'hFC; //Electrical Idle Exit (logical marker)
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
 
  =========================================================================================
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
 
  //Enum: ltssm_substate_e
  //Fine grained LTSSM sub-states for link initialization, training and speed change.
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
  //RECOVERY_RCVR_LOCK/RECOVERY_SPEED/RECOVERY_RCVR_CFG/RECOVERY_EQUALIZATION/RECOVERY_IDLE
  //are re-entered once per step of SPEED_UPGRADE_SEQUENCE when stepping up to GEN6.
  typedef enum logic [2:0] {
    RECOVERY_RCVR_LOCK,
    RECOVERY_RCVR_CFG,
    RECOVERY_SPEED,
    RECOVERY_EQUALIZATION,
    RECOVERY_IDLE
  } recovery_substate_e;
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
    OS_IDLE
  } os_type_e;
 
  k_state_e;
 
  //Enum: eq_phase_e
  //GEN3+ Transmitter Equalization phases performed during Recovery.Equalization
  typedef enum logic [1:0] {
    EQ_PHASE0,
    EQ_PHASE1,
    EQ_PHASE2,
    EQ_PHASE3
  } eq_phase_e;
 
  
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
 
  =========================================================================================
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
 
endpackage : pcie_phy_pkg
 
`endif
