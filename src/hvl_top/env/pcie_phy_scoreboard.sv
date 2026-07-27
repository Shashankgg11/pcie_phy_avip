`ifndef PCIE_PHY_SCOREBOARD_INCLUDED_
`define PCIE_PHY_SCOREBOARD_INCLUDED_

//--------------------------------------------------------------------------------------------
//  Class: pcie_phy_scoreboard
// Cross-checks RC and EP LTSSM state transitions / Ordered Set fields against each other
//--------------------------------------------------------------------------------------------
//A plain uvm_analysis_imp requires its implementation class to have exactly one method
//named write(T). This scoreboard needs two different write methods (one per tx type), so
//it uses the suffixed uvm_analysis_imp_decl macro instead - each declared suffix generates
//a uvm_analysis_imp<suffix> #(T, IMP) class whose write(T) calls IMP's write<suffix>(T).
`uvm_analysis_imp_decl(_rc)
`uvm_analysis_imp_decl(_ep)

class pcie_phy_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(pcie_phy_scoreboard)

  //Variable: pcie_phy_rc_analysis_export
  uvm_analysis_imp_rc #(pcie_phy_rc_tx, pcie_phy_scoreboard) pcie_phy_rc_analysis_export;

  //Variable: pcie_phy_ep_analysis_export
  uvm_analysis_imp_ep #(pcie_phy_ep_tx, pcie_phy_scoreboard) pcie_phy_ep_analysis_export;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_scoreboard", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual function void write_rc(pcie_phy_rc_tx t);
  extern virtual function void write_ep(pcie_phy_ep_tx t);

endclass : pcie_phy_scoreboard

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_scoreboard
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_scoreboard::new(string name = "pcie_phy_scoreboard", uvm_component parent = null);
  super.new(name, parent);
  pcie_phy_rc_analysis_export = new("pcie_phy_rc_analysis_export", this);
  pcie_phy_ep_analysis_export = new("pcie_phy_ep_analysis_export", this);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_scoreboard::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Function: write_rc
// <Description_here> — correlate RC-side LTSSM events against EP-side
//
// Parameters:
//  t - RC transaction
//--------------------------------------------------------------------------------------------
function void pcie_phy_scoreboard::write_rc(pcie_phy_rc_tx t);
  // TODO: LTSSM state cross-check, TS/EC field correlation
endfunction : write_rc

//--------------------------------------------------------------------------------------------
// Function: write_ep
// <Description_here> — correlate EP-side LTSSM events against RC-side
//
// Parameters:
//  t - EP transaction
//--------------------------------------------------------------------------------------------
function void pcie_phy_scoreboard::write_ep(pcie_phy_ep_tx t);
  // TODO: LTSSM state cross-check, TS/EC field correlation
endfunction : write_ep


`endif
