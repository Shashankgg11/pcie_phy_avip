`ifndef PCIE_PHY_PKG_INCLUDED_
`define PCIE_PHY_PKG_INCLUDED_
 
package pcie_phy_pkg;
 
  //=========================================================================================
  // Parameters
  //=========================================================================================
 
  //-------------------------------------------------------
  // Link and lane configuration
  //-------------------------------------------------------
  parameter int PCIE_MAX_LANES    = 16;  // Maximum lanes supported
  parameter int ACTIVE_LANES      = 4;   // Active link width
  parameter int MAX_LINK_WIDTH_RC = 16;  // Maximum RC link width
  parameter int MAX_LINK_WIDTH_EP = 16;  // Maximum EP link width
  parameter int MAX_LINK_SPEED    = 6;   // Maximum supported Gen
  parameter int SYMBOL_WIDTH      = 8;
 
  //-------------------------------------------------------
  // Ordered set and symbol lengths
  //-------------------------------------------------------
  parameter int TS_OS_LENGTH  = 16;  //TS1/TS2: 1 COM + 15 data symbols
  parameter int SKP_OS_LENGTH = 4;   //SKIP: 1 COM + 3 SKP
  parameter int FTS_OS_LENGTH = 4;
  parameter int EIOS_LENGTH   = 4;
  parameter int EIEOS_LENGTH  = 16;
  parameter int SDS_OS_LENGTH = 16;
  parameter bit [7:0] N_FTS_DEFAULT = 8'h3C;
 
  //-------------------------------------------------------
  // LTSSM timeouts and counters
  //-------------------------------------------------------
  parameter int DETECT_TIMEOUT_MS   = 12;
  parameter int POLLING_TIMEOUT_MS  = 24;
  parameter int CONFIG_TIMEOUT_MS   = 2;
  parameter int RECOVERY_TIMEOUT_MS = 24;
 
  parameter int TIMEOUT_LINKWIDTH_MS = 24; // Config.Linkwidth.Start/Accept timeout
  parameter int TIMEOUT_LANENUM_MS   = 2;  // Config.Lanenum.Wait/Accept timeout
  parameter int TIMEOUT_COMPLETE_MS  = 2;  // Config.Complete timeout
  parameter int TIMEOUT_IDLE_MS      = 2;  // Config.Idle timeout
 
  parameter int TS1_1024_COUNT      = 1024; // Number of TS1 sent in Polling.Active before timeout
                                             //back to Polling.Compliance with no response
  parameter int CONSEC_TS_REQUIRED  = 2;    // Matching TS count needed to advance
  parameter int CONSEC_TS_COUNT     = 8;    // Generic matching TS/Idle count
  parameter int CONSEC_TS2_COMPLETE = 8;    // TS2 count needed to exit Config.Complete
  parameter int MIN_TS2_TX_COMPLETE = 16;   // Minimum TS2 TX count before leaving Config.Complete
  parameter int MIN_IDLE_TX         = 16;   // Minimum Idle TX count before leaving Config.Idle
  parameter int MIN_IDLE_RX         = 8;    // Minimum Idle RX count before leaving Config.Idle
  parameter int IDLE_COUNT          = 8;    // Generic Idle count
 
  // Logical symbol IDs used for ordered sets and packets
  // Electrical bit encoding is not modeled here
  parameter bit [7:0] COM_SYMBOL   = 8'hBC; // Comma - ordered set start
  parameter bit [7:0] PAD_SYMBOL   = 8'hF7; // Pad - unused Link/Lane number
  parameter bit [7:0] TS1_ID_BYTE  = 8'h4A; // TS1 identifier
  parameter bit [7:0] TS2_ID_BYTE  = 8'h45; // TS2 identifier

  // Modified TS1/TS2 ID and EC values
  // Enabled once the speed reaches Gen3+
  parameter bit [7:0] MOD_TS1_ID = 8'h1E;
  parameter bit [7:0] MOD_TS2_ID = 8'h2D;

  // EC field values are in bits[7:6] of byte 5 in Modified TS
  parameter bit [7:0] EC_PHASE0_1 = 8'h40; // bits[7:6] = 01
  parameter bit [7:0] EC_PHASE2   = 8'h80; // bits[7:6] = 10
  parameter bit [7:0] EC_PHASE3   = 8'hC0; // bits[7:6] = 11
  parameter bit [7:0] EC_DONE     = 8'h00; // bits[7:6] = 00 - equalization complete

  parameter bit [7:0] IDLE_SYMBOL  = 8'h00; // Logical Idle data symbol
  parameter bit [7:0] EIE_SYM      = 8'hFC; // Electrical Idle Exit marker
  parameter bit [7:0] IDL_SYM      = 8'h7C; //Electrical Idle (K28.3) - EIOS content for
                                             //Recovery.Speed, distinct from EIE_SYM above
  parameter bit [7:0] SDS_SYM      = 8'hE1; // Start of Data Stream
  parameter bit [7:0] SKP_SYMBOL   = 8'hAA; // Skip symbol
  parameter bit [7:0] FTS_ID       = 8'h55; // FTS identifier
 
  //-------------------------------------------------------
  // NON_FLIT_MODE framing tokens - GEN3 to GEN5
  //-------------------------------------------------------
  parameter bit [7:0] STP_TOKEN = 8'hFB; // Start TLP
  parameter bit [7:0] SDP_TOKEN = 8'h5C; // Start DLLP
  parameter bit [7:0] END_TOKEN = 8'hFD; // End good
  parameter bit [7:0] EDB_TOKEN = 8'hFE; // End bad
 
  
  //-------------------------------------------------------
  // FLIT_MODE parameters - 256B Flit
  //-------------------------------------------------------
  parameter int FLIT_BYTES             = 256;
  parameter int FLIT_TLP_PAYLOAD_BYTES = 236;
  parameter int FLIT_DLP_BYTES         = 6;
  parameter int FLIT_CRC_BYTES         = 8;
  parameter int FLIT_FEC_BYTES         = 6;

  // Flit structure: TLP payload + DLP + CRC + FEC
  typedef struct packed {
    logic [(FLIT_TLP_PAYLOAD_BYTES*8)-1:0] tlp_payload;
    logic [(FLIT_DLP_BYTES*8)-1:0]         dlp;
    logic [(FLIT_CRC_BYTES*8)-1:0]         crc;
    logic [(FLIT_FEC_BYTES*8)-1:0]         fec;
  } flit_t;

 
  // Gen6 reference profile for x4 link
  parameter bit [7:0] SYM4_GEN6 = 8'h3F; // Advertised data rates and FLIT mode
  parameter bit [7:0] SYM5_GEN6 = 8'h60; // Training control settings
  parameter bit [7:0] NTFS_RC   = 8'h84; // RC N_FTS
  parameter bit [7:0] NTFS_EP   = 8'hC8; // EP N_FTS
 
  //-------------------------------------------------------
  // Electrical block assumptions
  //-------------------------------------------------------
  parameter bit RX_DETECT_ASSUMED            = 1'b1; // Detect.Quiet to Detect.Active
  parameter bit PLL_LOCK_ASSUMED              = 1'b1; // Recovery.Speed rate change completes
  parameter bit ELECTRICAL_IDLE_EXIT_ASSUMED  = 1'b1; // Based on EIEOS, not voltage sensing
  parameter bit EQ_DONE_ASSUMED               = 1'b1; // Equalization is assumed successful
 
  
  //=========================================================================================
  // ENUMS
  //=========================================================================================
 
  
  // Port type enum
  // Selects the RC or EP side
  typedef enum logic {
    PORT_RC = 1'b0,
    PORT_EP = 1'b1
  } port_type_e;
 
  // PCIe generation enum
  // Negotiated or advertised link speed
  typedef enum logic [2:0] {
    GEN1 = 3'd0, //2.5  GT/s
    GEN2 = 3'd1, //5.0  GT/s
    GEN3 = 3'd2, //8.0  GT/s
    GEN4 = 3'd3, //16.0 GT/s
    GEN5 = 3'd4, //32.0 GT/s
    GEN6 = 3'd5  //64.0 GT/s - FLIT Mode mandatory, PAM4 (electrical, out of scope)
  } pcie_gen_e;
 
  // Speed upgrade sequence
  // Order used to move from GEN1 to GEN6
  typedef pcie_gen_e speed_sequence_t [0:5];
  parameter speed_sequence_t SPEED_UPGRADE_SEQUENCE = '{GEN1, GEN2, GEN3, GEN4, GEN5, GEN6};

  // Minimum generation for mandatory FLIT mode
  // FLIT mode is mandatory from GEN6
  parameter pcie_gen_e FLIT_MODE_MANDATORY_FROM_GEN = GEN6;

  // Minimum generation that needs equalization
  // Equalization is required from this generation
  parameter pcie_gen_e EQ_REQUIRED_MIN_GEN = GEN3;
 
  // Link width enum
  // Negotiated link width
  typedef enum logic [5:0] {
    X1  = 6'd1,
    X2  = 6'd2,
    X4  = 6'd4,
    X8  = 6'd8,
    X12 = 6'd12,
    X16 = 6'd16,
    X32 = 6'd32
  } link_width_e;
 
  // LTSSM state enum
  // Main LTSSM states
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
 
  // Each LTSSM state with sub-states has its own enum
 
  // Detect state sub-states
  typedef enum logic [2:0] {
    DETECT_QUIET,
    DETECT_ACTIVE
  } detect_substate_e;
 
  // Polling state sub-states
  typedef enum logic [2:0] {
    POLLING_ACTIVE,
    POLLING_CONFIG,
    POLLING_COMPLIANCE
  } polling_substate_e;
 
  // Configuration state sub-states
  typedef enum logic [2:0] {
    CFG_LINKWIDTH_START,
    CFG_LINKWIDTH_ACCEPT,
    CFG_LANENUM_WAIT,
    CFG_LANENUM_ACCEPT,
    CFG_COMPLETE,
    CFG_IDLE
  } config_substate_e;
 
  // Recovery state sub-states used for each speed step
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
 
  // Loopback state sub-states
  typedef enum logic [2:0] {
    LOOPBACK_ENTRY,
    LOOPBACK_ACTIVE,
    LOOPBACK_EXIT
  } loopback_substate_e;
 
  // L0s state sub-states
  typedef enum logic [2:0] {
    TX_L0S_ENTRY,
    TX_L0S_IDLE,
    TX_L0S_FTS,
    RX_L0S_ENTRY,
    RX_L0S_IDLE,
    RX_L0S_FTS
  } l0s_substate_e;
 
  
 
 
  // Next LTSSM action enum
  // Next state decision from each run_* task
  typedef enum logic [3:0] {
    NEXT_NONE         = 4'd0, // Move to the next sub-state
    NEXT_COMPLETE     = 4'd1,
    NEXT_LANENUM_WAIT = 4'd2,
    NEXT_DETECT       = 4'd3, // Timeout or link down -> Detect
    NEXT_L0           = 4'd4,
    NEXT_DISABLED     = 4'd5,
    NEXT_LOOPBACK     = 4'd6,
    NEXT_HOT_RESET    = 4'd7,
    NEXT_RECOVERY     = 4'd8  // Speed change or retrain request
  } ltssm_next_action_e;
 
  // Ordered set type enum
  // Ordered sets used during link training and speed changes
  typedef enum logic [3:0] {
    OS_NONE,
    OS_TS1,
    OS_TS2,
    OS_MODIFIED_TS,               // Modified TS1/TS2 format
    OS_SKIP,
    OS_EIOS,
    OS_EIEOS,
    OS_FTS,
    OS_SDS,
    OS_COMPLIANCE,
    OS_MODIFIED_COMPLIANCE,
    OS_IDLE
  } os_type_e;
 

  // Equalization phase enum
  // Equalization phases for Gen3+
  typedef enum logic [1:0] {
    EQ_PHASE0,
    EQ_PHASE1,
    EQ_PHASE2,
    EQ_PHASE3
  } eq_phase_e;
 
    //Enum: pipe_rate_e
  // Logical rate request on PIPE
  typedef enum logic [3:0] {
    PIPE_RATE_GEN1 = 4'h0,
    PIPE_RATE_GEN2 = 4'h1,
    PIPE_RATE_GEN3 = 4'h2,
    PIPE_RATE_GEN4 = 4'h3,
    PIPE_RATE_GEN5 = 4'h4,
    PIPE_RATE_GEN6 = 4'h5
  } pipe_rate_e;

  // Debug selector used to call driver BFM tasks directly
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

  // LTSSM status structure
  // BFM status with LTSSM state and link-up flag
  typedef struct packed {
    ltssm_state_e state;
    logic         link_up;
  } ltssm_status_t;

  // BFM configuration structure
  // Config used to pass rate and lane settings to the driver BFM
  typedef struct packed {
    bit [6:0] supported_rates;
    bit       flit_mode_supported;
    bit [4:0] active_lanes;
  } pcie_phy_bfm_cfg_s;
 
  
  // Other link conditions
  // Link conditions tracked during training
  typedef enum logic [1:0] {
    LINK_UP,
    UP_CONFIGURE,
    WIDTH_CHANGE
  } other_condition_e;
 
  // Encoding type enum
  // Encoding used at the negotiated speed
  typedef enum logic [1:0] {
    ENC_8B10B,    // Gen1 to Gen2
    ENC_128B130B, // Gen3 to Gen5, non-FLIT mode
    ENC_FLIT      // FLIT mode
  } encoding_type_e;
 
  // Data transfer mode enum
  // Framing mode used for data transfer in L0
  typedef enum logic {
    NON_FLIT_MODE = 1'b0, // Legacy framed TLPs/DLLPs
    FLIT_MODE     = 1'b1  // Fixed 256B Flits
  } data_transfer_mode_e;
 
  // Flit content enum
  // Data carried by a Flit
  typedef enum logic [1:0] {
    LOGICAL_IDLE_FLIT,  // No upper layer data
    DATA_FLIT,          // Carries TLP/DLLP data
    SKP_ORDERED_SET     // Periodic SKP ordered set
  } flit_content_e;
 
  // Packed structures
 
  // TS ordered set structure
  // Decoded TS1/TS2 fields used by RC and EP
  typedef struct packed {
    os_type_e  os_type;
    logic [7:0] link_number;
    logic [7:0] lane_number;
    logic [7:0] n_fts;
    pcie_gen_e data_rate;
    logic      speed_change;         // Symbol4 Bit7 - requests Recovery.Speed
    logic      autonomous_change;
    logic      disable_scrambling;
    logic      loopback;
    logic      disable_link;
    logic      hot_reset;
    logic      select_deemphasis;
    logic      compliance_receive;
    logic      flit_mode_supported;  // Symbol4 Bit0 - FLIT mode support
    logic [3:0] tx_preset;
    logic [2:0] rx_preset_hint;
  } ts_ordered_set_t;
 
  // Raw TS1/TS2 ordered set structure
  // TS1/TS2 symbols used to build and compare the transmitted data
  typedef struct packed {
    logic [7:0] sym0_com;
    logic [7:0] sym1_link_number;
    logic [7:0] sym2_lane_number;
    logic [7:0] sym3_n_fts;
    logic [7:0] sym4_data_rate_id;
    logic [7:0] sym5_training_ctrl;
    logic [9:0][7:0] sym6_15_identifier; // 10 identifier bytes
  } ts_ordered_set_bytes_t;
 
  // Modified TS structure with the main 7 bytes
  typedef struct packed {
    logic [7:0] id;           // byte0: Modified TS ID
    logic [7:0] link_number;  // byte1: Link number
    logic [7:0] lane_number;  // byte2: Lane number
    logic [7:0] n_fts;        // byte3: N_FTS
    logic [7:0] data_rate_id; //byte4 - bit7 is still speed_change (SC), same position as
                               //the standard format
    logic [7:0] ec_byte;      // byte5 - EC field for the Modified TS format
    logic [7:0] payload;      // byte6 - data depends on the equalization phase
  } modified_ts_bytes_t;
 
  // Symbol 4 structure
  // Symbol 4 bit fields
  typedef struct packed {
    logic speed_change;        // Bit7
    logic autonomous_change;   //Bit6
    logic speed_32gts;         //Bit5
    logic speed_16gts;         // Bit4
    logic speed_8gts;          //Bit3
    logic speed_5gts;          // Bit2
    logic speed_2p5gts;        // Bit1
    logic flit_mode_supported; // Bit0
  } sym4_data_rate_t;
 
  // Symbol 5 structure
  // Symbol 5 bit fields
  typedef struct packed {
    logic reserved_7;
    logic elbc_hi;        // Bit6 - ELBC[1]
    logic elbc_lo;        // Bit5 - ELBC[0]
    logic no_scrambling;  // Bit4
    logic reserved_3;
    logic loopback;       // Bit2
    logic disable_link;   // Bit1
    logic hot_reset;      // Bit0
  } sym5_training_ctrl_t;
 
  // Speed capability structure
  // Speed and FLIT capability bits
  typedef struct packed {
    logic gen1_support;
    logic gen2_support;
    logic gen3_support;
    logic gen4_support;
    logic gen5_support;
    logic gen6_support;
    logic flit_support;
  } speed_cap_t;
 
  // Speed change structure
  // Speed change state for one Recovery pass
  typedef struct packed {
    pcie_gen_e current_speed;
    pcie_gen_e target_speed;
    logic      start_change;
    logic      speed_done;
  } speed_change_t;
 
 
  typedef enum bit {
    RD_MINUS = 1'b0, //more 0s than 1s sent so far (or balanced) - next control/data symbol
                      //uses the RD- encoding
    RD_PLUS  = 1'b1  // More 1s than 0s, so use RD+
  } running_disparity_e;
 
  //-------------------------------------------------------
  // K-code encoded pairs
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
  parameter bit [9:0] K_IDL_P = 10'b1100001100; // K28.3
  parameter bit [9:0] K_IDL_N = 10'b0011110011;
 
  // D-code lookup tables for byte values 0 to 255
  // Encodings for RD_MINUS and RD_PLUS
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
 
  // LTSSM task selector used to call driver BFM tasks
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

  // Set to 1 to leave Polling.Compliance
  bit exit_compliance_req;

  // Set to 1 to force L0 to Recovery
  bit recovery_request;

  // Flags used by RC and EP to wait for each other before changing states
  //-------------------------------------------------------
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

  // Reason for entering Recovery
  typedef enum {
    RECOVERY_REASON_NONE,
    RECOVERY_REASON_SPEED_CHANGE,     // Current speed is different from target speed
    RECOVERY_REASON_DIRECTED,         // Directed recovery request
    RECOVERY_REASON_ERROR_THRESHOLD,  // Too many receive errors in L0
    RECOVERY_REASON_IDLE_TIMEOUT,     // Idle was not received for too long
    RECOVERY_REASON_PARTNER_INITIATED // Partner sent TS1 while still in L0
  } recovery_reason_e;

endpackage : pcie_phy_pkg
 
`endif
