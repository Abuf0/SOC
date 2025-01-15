module clgate_cell(
    input  clkin     ,
    input  enable    ,
    input  scan_en   ,
    output clkout
);

`ifdef FPGA
wire en_in = scan_en | enable;
reg latch_en;
always @(clkin or en_in) begin
    if(~clkin)  latch_en <= en_in;
end
assign clkout = clkin & latch_en;

`else
    // instantiate a clock gate stdcell //

`endif

endmodule