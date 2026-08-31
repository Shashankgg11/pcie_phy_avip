`ifndef PCIE_PHY_SCOREBOARD_INCLUDED_
`define PCIE_PHY_SCOREBOARD_INCLUDED_

//--------------------------------------------------------------------------------------------
//  Class: pcie_phy_scoreboard
//--------------------------------------------------------------------------------------------
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
//--------------------------------------------------------------------------------------------
function pcie_phy_scoreboard::new(string name = "pcie_phy_scoreboard", uvm_component parent = null);
  super.new(name, parent);
  pcie_phy_rc_analysis_export = new("pcie_phy_rc_analysis_export", this);
  pcie_phy_ep_analysis_export = new("pcie_phy_ep_analysis_export", this);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_scoreboard::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Function: write_rc

//--------------------------------------------------------------------------------------------
function void pcie_phy_scoreboard::write_rc(pcie_phy_rc_tx t);
  // TODO: LTSSM state cross-check, TS/EC field correlation
endfunction : write_rc

//--------------------------------------------------------------------------------------------
// Function: write_ep
//--------------------------------------------------------------------------------------------
function void pcie_phy_scoreboard::write_ep(pcie_phy_ep_tx t);
  // TODO: LTSSM state cross-check, TS/EC field correlation
endfunction : write_ep


`endif
