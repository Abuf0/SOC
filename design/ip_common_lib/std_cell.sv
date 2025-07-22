module ckmux(
    input   in0,
    input   in1,
    input   sel,
    output  out
);
`ifdef FPGA
assign out = sel?   in1 : in0;
`else
    // instantiate a ckmux stdcell //
`endif

endmodule