/*  This file is part of JTFRAME.
      JTFRAME program is free software: you can redistribute it and/or modify
      it under the terms of the GNU General Public License as published by
      the Free Software Foundation, either version 3 of the License, or
      (at your option) any later version.

      JTFRAME program is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
      MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
      GNU General Public License for more details.

      You should have received a copy of the GNU General Public License
      along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

      Author: Jose Tejada Gomez. Twitter: @topapate
      Version: 1.0
      Date: 21-5-2021

*/

module jtframe_8751mcu(
    input         rst,
    input         clk,
    input         cen,

    input         int0n,
    input         int1n,

    input  [ 7:0] p0_i,
    input  [ 7:0] p1_i,
    input  [ 7:0] p2_i,
    input  [ 7:0] p3_i,

    output [ 7:0] p0_o,
    output [ 7:0] p1_o,
    output [ 7:0] p2_o,
    output [ 7:0] p3_o,

    // external memory
    input      [ 7:0] x_din,
    output reg [ 7:0] x_dout,
    output reg [15:0] x_addr,
    output reg        x_wr,
    output reg        x_acc,

    // ROM programming
    input         clk_rom,
    input [11:0]  prog_addr,
    input [ 7:0]  prom_din,
    input         prom_we
);

parameter ROMBIN="",
          SINC_XDATA = 0;

wire [ 7:0] rom_data, ram_data, ram_q;
reg  [15:0] rom_addr;
wire [ 6:0] ram_addr;
wire        ram_we;
reg  [ 7:0] xin_sync, p0_s, p1_s, p2_s, p3_s;   // input data must be sampled with cen

always @(posedge clk) if(cen) begin
    xin_sync <= x_din;
    p0_s     <= p0_i;
    p1_s     <= p1_i;
    p2_s     <= p2_i;
    p3_s     <= p3_i;
end

// You need to clock gate for reading or the MCU won't work
jtframe_dual_ram_cen #(.aw(12),.simfile(ROMBIN)) u_prom(
    .clk0   ( clk_rom   ),
    .cen0   ( 1'b1      ),
    .clk1   ( clk       ),
    .cen1   ( cen       ),
    // Port 0
    .data0  ( prom_din  ),
    .addr0  ( prog_addr ),
    .we0    ( prom_we   ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( rom_addr[11:0]  ),
    .we1    ( 1'b0      ),
    .q1     ( rom_data  )
);

jtframe_ram #(.aw(7),.cen_rd(1)) u_ramu(
    .clk        ( clk               ),
    .cen        ( cen               ),
    .addr       ( ram_addr          ),
    .data       ( ram_data          ),
    .we         ( ram_we            ),
    .q          ( ram_q             )
);

wire [ 7:0] pre_dout;
wire [15:0] pre_addr, pre_rom;
wire        pre_wr, pre_acc;

always @(posedge clk) begin
    x_addr   <= pre_addr;
    x_wr     <= pre_wr;
    x_dout   <= pre_dout;
    x_acc    <= pre_acc;
    rom_addr <= pre_rom;
end

mc8051_core u_mcu(
    .reset      ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    // code ROM
    .rom_data_i ( rom_data  ),
    .rom_adr_o  ( pre_rom   ),
    // internal RAM
    .ram_data_i ( ram_q     ),
    .ram_data_o ( ram_data  ),
    .ram_adr_o  ( ram_addr  ),
    .ram_wr_o   ( ram_we    ),
    .ram_en_o   (           ),
    // external memory: connected to main CPU
    .datax_i    ( SINC_XDATA ? xin_sync : x_din ),
    .datax_o    ( pre_dout  ),
    .adrx_o     ( pre_addr  ),
    .wrx_o      ( pre_wr    ),
    .memx_o     ( pre_acc   ),
    // interrupts
    .int0_i     ( int0n     ),
    .int1_i     ( int1n     ),
    // counters
    .all_t0_i   ( 1'b0      ),
    .all_t1_i   ( 1'b0      ),
    // serial interface
    .all_rxd_i  ( 1'b0      ),
    .all_rxd_o  (           ),
    // Ports
    .p0_i       ( p0_i      ),
    .p0_o       ( p0_o      ),

    .p1_i       ( p1_i      ),
    .p1_o       ( p1_o      ),

    .p2_i       ( p2_i      ),
    .p2_o       ( p2_o      ),

    .p3_i       ( p3_i      ),
    .p3_o       ( p3_o      )
);

endmodule