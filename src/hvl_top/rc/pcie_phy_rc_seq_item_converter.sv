`ifndef PCIE_PHY_RC_SEQ_ITEM_CONVERTER_INCLUDED_
`define PCIE_PHY_RC_SEQ_ITEM_CONVERTER_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_seq_item_converter
// Converts pcie_phy_rc_tx <-> BFM-side packet struct
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_seq_item_converter extends uvm_object;
  `uvm_object_utils(pcie_phy_rc_seq_item_converter)

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_seq_item_converter");

endclass : pcie_phy_rc_seq_item_converter

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_rc_seq_item_converter
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_seq_item_converter::new(string name = "pcie_phy_rc_seq_item_converter");
  super.new(name);
endfunction : new


`endif
