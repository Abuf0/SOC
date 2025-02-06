module lp_pulse_sync #(
    parameter NUM = 4
)(
    input                   clk_src            ,
    input                   rstn_src           ,
    input                   clk_dst            ,
    input                   rstn_dst           ,
    input                   scan_en            ,
    input [NUM-1:0]         pulse_async_in     ,
    output logic [NUM-1:0]  pulse_sync_out      
);

`ifdef USE_ICG
logic pulse_on_src;
logic togg;
logic togg_sync;
logic togg_sync_d1;
logic pulse_on_dst;
logic pulse_on_dst_d1;
logic clk_dst_gt;

assign pulse_on_src = |pulse_async_in;
always@(posedge clk_src or negedge rstn_src) begin
    if(~rstn_src)
        togg <= 1'b0;
    else 
        togg <= pulse_on_src?   ~togg : togg;
end
sync_level sync_togg_inst(.clk(clk_dst),.rstn(rstn_dst),.level_in(togg),.level_out(togg_sync));

always@(posedge clk_dst or negedge rstn_dst) begin
    if(~rstn_dst)
        togg_sync_d1 <= 1'b0;
    else 
        togg_sync_d1 <= togg_sync;
end
assign pulse_on_dst = togg_sync_d1 ^ togg_sync;

always@(posedge clk_dst or negedge rstn_dst) begin
    if(~rstn_dst)
        pulse_on_dst_d1 <= 1'b0;
    else 
        pulse_on_dst_d1 <= pulse_on_dst;
end
assign icg_enable = pulse_on_dst | pulse_on_dst_d1;
ckgate_cell u_clk_icg_psync (.clkin(clk_dst),  .enable(icg_enable), .scan_en(scan_en), .clkout(clk_dst_gt));

logic [NUM-1:0] togg_lp;
logic [NUM-1:0] togg_lp_sync;
logic [NUM-1:0] togg_lp_sync_d1;

genvar i;
generate 
    for(i=0;i<NUM;i=i+1) begin
        always@(posedge clk_src or negedge rstn_src) begin
            if(~rstn_src)
                togg_lp[i] <= 1'b0;
            else 
                togg_lp[i] <= pulse_async_in[i]?   ~togg_lp[i] : togg_lp[i];
        end
        always@(posedge clk_dst_gt or negedge rstn_dst) begin   // no need to sync level
            if(~rstn_dst)
                togg_lp_sync[i] <= 1'b0;
            else
                togg_lp_sync[i] <= togg_lp[i];
        end
        always@(posedge clk_dst_gt or negedge rstn_dst) begin
            if(~rstn_dst)
                togg_lp_sync_d1[i] <= 1'b0;
            else
                togg_lp_sync_d1[i] <= togg_lp_sync[i];
        end        
        assign pulse_sync_out[i] = togg_lp_sync_d1[i] ^ togg_lp_sync[i];
    end
endgenerate

`else

logic [NUM-1:0] togg;
logic [NUM-1:0] togg_sync;
logic [NUM-1:0] togg_sync_d1;

genvar i;
generate 
    for(i=0;i<NUM;i=i+1) begin
        always@(posedge clk_src or negedge rstn_src) begin
            if(~rstn_src)
                togg[i] <= 1'b0;
            else 
                togg[i] <= pulse_async_in[i]?   ~togg[i] : togg[i];
        end

        sync_level sync_togg_inst(.clk(clk_dst),.rstn(rstn_dst),.level_in(togg[i]),.level_out(togg_sync[i])); // need to sync level

        always@(posedge clk_dst or negedge rstn_dst) begin
            if(~rstn_dst)
                togg_sync_d1[i] <= 1'b0;
            else
                togg_sync_d1[i] <= togg_sync[i];
        end        

        assign pulse_sync_out[i] = togg_sync_d1[i] ^ togg_sync[i];
    end
endgenerate


`endif

`ifdef ASSERT_ON    
                  
generate 
    for (genvar j = 0; j <NUM; j++) begin 
        property lp_pulse_sync_assert;
            @ (posedge clk_dst) disable iff(!rstn_dst)
            (pulse_async_in[j]) |-> ##[1:3] ($rose(pulse_sync_out[j])) |-> ##1 $fell(pulse_sync_out[j]) ;
        endproperty
        assert property(lp_pulse_sync_assert)    
            $display("pulse_sync passed",$time); 
        else
            $display("pulse_sync error",$time);          
    end
endgenerate

`endif


endmodule