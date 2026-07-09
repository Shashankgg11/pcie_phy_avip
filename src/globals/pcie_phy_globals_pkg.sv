`ifndef PCIE_PHY_GLOBALS_PKG_INCLUDED_
`define PCIE_PHY_GLOBALS_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package: pcie_phy_globals_pkg
// All LTSSM enums, parameters, types (spec Parts 1-6)
//--------------------------------------------------------------------------------------------
package pcie_phy_globals_pkg;

  // ─── Parameters ───────────────────────────────────────
  parameter int NUM_LANES        = 4;
  parameter int PCIE_MAX_LANES   = 16;
  parameter logic [7:0] COM_SYMBOL  = 8'hBC;
  parameter logic [7:0] PAD_SYMBOL  = 8'hF7;
  parameter logic [7:0] TS1_ID_BYTE = 8'h4A;
  parameter logic [7:0] TS2_ID_BYTE = 8'h45;
  parameter logic [7:0] NTFS_RC     = 8'h84;
  parameter logic [7:0] NTFS_EP     = 8'hC8;

  // ─── Top-level LTSSM states (Figure 4-48) ─────────────
  typedef enum logic [4:0] {
    DETECT, POLLING, CONFIGURATION, L0, L0S, L1, L2,
    RECOVERY, HOT_RESET, DISABLED, LOOPBACK
  } ltssm_state_e;

  // ─── Sub-states ────────────────────────────────────────
  typedef enum logic [1:0] { DET_QUIET, DET_ACTIVE } detect_substate_e;
  typedef enum logic [1:0] { POLL_ACTIVE, POLL_COMPLIANCE, POLL_CONFIGURATION } polling_substate_e;
  typedef enum logic [3:0] {
    CFG_LINKWIDTH_START, CFG_LINKWIDTH_ACCEPT, CFG_LANENUM_WAIT,
    CFG_LANENUM_ACCEPT, CFG_COMPLETE, CFG_IDLE
  } cfg_substate_e;
  typedef enum logic [2:0] { RCVRLOCK, EQUALIZATION, SPEED, RCVRCFG, IDLE } recovery_substate_e;
  typedef enum logic [1:0] { EQ_PHASE0, EQ_PHASE1, EQ_PHASE2, EQ_PHASE3 } eq_phase_e;
  typedef enum logic [1:0] { EC_00, EC_01, EC_10, EC_11 } ec_field_e;

  // ─── Port / rate ───────────────────────────────────────
  typedef enum logic { PORT_RC = 1'b0, PORT_EP = 1'b1 } port_type_e;
  typedef enum logic [2:0] { RATE_2P5GT, RATE_5GT, RATE_8GT, RATE_16GT, RATE_32GT, RATE_64GT } link_rate_e;

  // ─── Generic next-state decision ──────────────────────
  typedef enum logic [3:0] {
    NEXT_NONE, NEXT_DETECT, NEXT_POLLING, NEXT_CONFIGURATION,
    NEXT_RECOVERY, NEXT_L0, NEXT_L0S, NEXT_L1, NEXT_L2,
    NEXT_DISABLED, NEXT_HOT_RESET, NEXT_LOOPBACK
  } next_state_e;

endpackage : pcie_phy_globals_pkg

`endif
