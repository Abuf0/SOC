module mpx_hgt
#(
    parameter DIV_WID = 4
)(
    input               rg_mpx_en           ,
    input [1:0]         rg_mpx_sel          ,
    input               clk                 ,
    input               rstn                ,
    input               scan_en             ,
    input [DIV_WID-1:0] div_dat_even    ,
    input               mpx_in              ,
    output logic        mpx_out
);
logic counter_hit;
logic clk_div;
logic clk_dbg;
assign mpx_out = (rg_mpx_sel == 2'd0)?  counter_hit :
                 (rg_mpx_sel == 2'd1)?  clk_dbg :
                 (rg_mpx_sel == 2'd2)?  mpx_in : 1'b0;

counter_level_clr_1 counter_level_clr_1_mpx_inst(
    .clk            (clk            ),
    .rstn           (rstn           ),
    .scan_en        (0              ),
    .enable         (1'b1           ),
    .counter_out    (counter_hit    )
);

`ifdef USE_ICG
logic clk_gt;
logic icg_enable;
assign icg_enable = rg_mpx_en && (rg_mpx_sel == 2'd1);
ckgate_cell u_clk_icg_div (.clkin(clk),  .enable(icg_enable), .scan_en(scan_en), .clkout(clk_gt));

div_clk #( .DIV_WID(4) ) div_clk_mpx_inst(
    .clk            (clk_gt       ),
    .rstn           (rstn         ),
    .div_dat_even   (div_dat_even ),
    .clk_div_o      (clk_dbg      )
);

`else
div_clk #( .DIV_WID(4) ) div_clk_mpx_inst(
    .clk            (clk          ),
    .rstn           (rstn         ),
    .div_dat_even   (div_dat_even ),
    .clk_div_o      (clk_dbg      )
);
`endif

`ifdef ASSERT_ON

assert property(mpx_assert_0)       
    $display("mpx 0 out passed",$time);          
else
    $display("mpx 0 out error",$time);           

assert property(mpx_assert_1)       
    $display("mpx 1 out passed",$time);     
else
    $display("mpx 1 out error",$time);      

assert property(mpx_clock_chk_assert(mpx_out,(rg_mpx_en && rg_mpx_sel==1),`CLK_PERIOD*div_dat_even,0,0.5,0))       
    $display("mpx clk out passed",$time);   
else
    $display("mpx clk out error",$time);    

assert property(mpx_assert_2)       
    $display("mpx 2 out passed",$time);   
else
    $display("mpx 2 out error",$time);    

property mpx_assert_0;
    @ (posedge clk) disable iff(!rstn)
    (rg_mpx_en && rg_mpx_sel == 0) |-> (mpx_out == counter_hit) ;
endproperty

property mpx_assert_1;
    @ (posedge clk) disable iff(!rstn)
    (rg_mpx_en && rg_mpx_sel == 1) |-> ##[0:`CLK_PERIOD*(1 << DIV_WID)] (mpx_out) ;
endproperty

property mpx_clock_chk_assert(chk_clk,chk_en,prd,prd_margin,duty,duty_margin);
    realtime t0,t1,t2;
    @(edge chk_clk) disable iff(!chk_en)
    (chk_clk===1, t0=$realtime) |=> (chk_clk===0, t1=$realtime) ##1 (chk_clk===1,t2=$realtime)
    ##0 (((t2-t1)/(t2-t0)) >= (duty-duty_margin)) && (((t2-t1)/(t2-t0)) <= (duty+duty_margin))
    ##0 ((t2-t0) >= (prd-prd_margin)) && ((t2-t0) <= (prd+prd_margin));
endproperty

property mpx_assert_2;
    @ (posedge clk) disable iff(!rstn)
    (rg_mpx_en && rg_mpx_sel == 2) |-> (mpx_out == mpx_in) ;
endproperty

`endif

endmodule