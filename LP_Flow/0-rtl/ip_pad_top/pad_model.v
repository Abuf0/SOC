module pad_s1(
    input I,
    input OEN,
    input IEN,
    input PUE,
    input PDE,
    input POR_N,
    output O,
    input IO
);
parameter DLY_OUT_UD = 0;
parameter DLY_IN_UD  = 0;
`ifdef FPGA
    assign IO = OEN?  I : 1'bz;
    assign O = POR_N & IEN & IO;
`else 
    supply1 my1;
    supply0 my0;
    bufif1 #DLY_OUT_UD (C_buff, I, OEN);
    pmos(IO, C_buff, my0);
    and(IE_i, IEN, POR_N);
    and #DLY_IN_UD (O, IO, IE_i);
    not(PU_N, PUE);
    rpmos #0.01(C_buff, my1, PU_N);
    rnmos #0.01(C_buff, my0, PUE);
    //always @(IO) begin
    //    if(IO === 1'bx && !$test$plusargs("bus_conflict_off") && $countdrivers(IO))
    //        $display("%t -- BUS CONFLICT -- :%m", $realtime);
    //end
`endif

endmodule
