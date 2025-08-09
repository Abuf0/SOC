module pad_top(
    // SCK, CSN, MISO, MOSI, INT, MPX, VDD... //
    input   miso_out,
    input   int_out,
    input   mpx_out,
    output  sck_in,
    output  csn_in,
    output  mosi_in,
    input   ad_por_n,
    inout   PAD_SCK,
    inout   PAD_CSN,
    inout   PAD_MISO,
    inout   PAD_MOSI,
    inout   PAD_INT,
    inout   PAD_MPX,
    inout   VDD,
    inout   VSS
);

pad_s1 PAD_SCK_inst(
    .I      (1'b0       ),
    .OEN    (1'b0       ),
    .IEN    (1'b1       ),
    .PUE    (1'b0       ),
    .PDE    (1'b1       ),
    .POR_N  (ad_por_n   ),
    .O      (sck_in     ),
    .IO     (PAD_SCK    )
);

pad_s1 PAD_CSN_inst(
    .I      (1'b0       ),
    .OEN    (1'b0       ),
    .IEN    (1'b1       ),
    .PUE    (1'b1       ),
    .PDE    (1'b0       ),
    .POR_N  (ad_por_n   ),
    .O      (csn_in     ),
    .IO     (PAD_CSN    )
);

pad_s1 PAD_MISO_inst(
    .I      (miso_out   ),
    .OEN    (1'b1       ),
    .IEN    (1'b0       ),
    .PUE    (1'b0       ),
    .PDE    (1'b1       ),
    .POR_N  (ad_por_n   ),
    .O      (           ),
    .IO     (PAD_MISO   )
);

pad_s1 PAD_MOSI_inst(
    .I      (1'b0       ),
    .OEN    (1'b0       ),
    .IEN    (1'b1       ),
    .PUE    (1'b0       ),
    .PDE    (1'b1       ),
    .POR_N  (ad_por_n   ),
    .O      (mosi_in    ),
    .IO     (PAD_MOSI   )
);

pad_s1 PAD_INT_inst(
    .I      (int_out    ),
    .OEN    (1'b1       ),
    .IEN    (1'b0       ),
    .PUE    (1'b0       ),
    .PDE    (1'b1       ),
    .POR_N  (ad_por_n   ),
    .O      (           ),
    .IO     (PAD_INT    )
);

pad_s1 PAD_MPX_inst(
    .I      (mpx_out    ),
    .OEN    (1'b1       ),
    .IEN    (1'b0       ),
    .PUE    (1'b0       ),
    .PDE    (1'b1       ),
    .POR_N  (ad_por_n   ),
    .O      (           ),
    .IO     (PAD_MPX    )
);

endmodule