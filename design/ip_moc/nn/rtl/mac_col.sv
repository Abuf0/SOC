module mac_col #(
    parameter ROW_NUM   = 32    ,
    parameter IN_WD     = 32*8  ,
    parameter WGT_WD    = 32*8  ,
    parameter MAX_WD    = 32    ,
    parameter OUT_WD    = 12
)(
    input                       clk             ,
    input                       rstn            ,
    input [IN_WD-1:0]           data_in         ,
    input                       data_in_vld     ,
    input [IN_WD-1:0]           data_in_mask    ,
    input [3:0]                 data_type       ,   // [3]: i/u, [1:0] :8,16,32
    input [WGT_WD-1:0]          wgt_in          ,
    input                       wgt_in_vld      ,
    input                       wgt_in_flag     ,   // 0: RWA, 1: RWB
    input [WGT_WD-1:0]          wgt_in_mask     ,
    input [3:0]                 wgt_type        ,
    input [ROW_NUM-1:0]         row_mask        , 
    input                       pingpong_flag   ,   // 0: A, 1: B
    output logic [OUT_WD-1:0]   data_out        ,
    output logic                data_out_vld
);

logic signed [MAX_WD-1:0] RWA [0:ROW_NUM-1];
logic signed [MAX_WD-1:0] RWB [0:ROW_NUM-1];
logic signed [MAX_WD-1:0] data_used [0:ROW_NUM-1];
logic signed [MAX_WD-1:0] weight_used [0:ROW_NUM-1];
logic signed [MAX_WD*2-1:0] mult_out [0:ROW_NUM-1];
logic signed [OUT_WD-1:0] sum_out;
logic data_in_vld_d1;

logic [WGT_WD-1:0] wgt_masked;
logic [IN_WD-1:0] data_masked;

assign wgt_masked = wgt_in & wgt_in_mask;
assign data_masked = data_in & data_in_mask;

// ARRAY //
genvar i;
generate
    for(i=0;i<ROW_NUM;i=i+1) begin: MAC_UINT
    // mapping weight //
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                RWA[i] <= 'sd0;
            else if(wgt_in_vld && ~wgt_in_flag) begin
                if(~row_mask[i]) 
                    RWA[i] <= 'sd0;
                else begin
                    case(wgt_type)
                        3'b000: // uint8
                            RWA[i] <= {{(MAX_WD-8){1'b0}},wgt_masked[i*8+7,i*8]};
                        3'b001: // uint16
                            RWA[i] <= {{(MAX_WD-16){1'b0}},wgt_masked[i*16+15,i*16]};
                        3'b010: // uint32
                            RWA[i] <= {{(MAX_WD-32){1'b0}},wgt_masked[i*32+31,i*32]};
                        3'b100: // int8
                            RWA[i] <= {{(MAX_WD-8){wgt_masked[i*8+7]}},wgt_masked[i*8+7,i*8]};
                        3'b101: // int16
                            RWA[i] <= {{(MAX_WD-16){wgt_masked[i*16+15]}},wgt_masked[i*16+15,i*16]};
                        3'b110: // int32
                            RWA[i] <= {{(MAX_WD-32){wgt_masked[i*32+31]}},wgt_masked[i*32+31,i*32]};
                        default:
                            RWA[i] <= {{(MAX_WD-8){1'b0}},wgt_masked[i*8+7,i*8]};
                    endcase
                end
            end
        end
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                RWB[i] <= 'sd0;
            else if(wgt_in_vld && wgt_in_flag) begin
                if(~row_mask[i]) 
                    RWB[i] <= 'sd0;
                else begin
                    case(wgt_type)
                        3'b000: // uint8
                            RWB[i] <= {{(MAX_WD-8){1'b0}},wgt_masked[i*8+7,i*8]};
                        3'b001: // uint16
                            RWB[i] <= {{(MAX_WD-16){1'b0}},wgt_masked[i*16+15,i*16]};
                        3'b010: // uint32
                            RWB[i] <= {{(MAX_WD-32){1'b0}},wgt_masked[i*32+31,i*32]};
                        3'b100: // int8
                            RWB[i] <= {{(MAX_WD-8){wgt_masked[i*8+7]}},wgt_masked[i*8+7,i*8]};
                        3'b101: // int16
                            RWB[i] <= {{(MAX_WD-16){wgt_masked[i*16+15]}},wgt_masked[i*16+15,i*16]};
                        3'b110: // int32
                            RWB[i] <= {{(MAX_WD-32){wgt_masked[i*32+31]}},wgt_masked[i*32+31,i*32]};
                        default:
                            RWB[i] <= {{(MAX_WD-8){1'b0}},wgt_masked[i*8+7,i*8]};
                    endcase
                end
            end
        end
    // mapping data //
        always_ff@(posedge clk or negedge rstn) begin
            if(~rstn)
                data_used[i] <= 'sd0;
            else if(data_in_vld) begin
                if(~row_mask[i]) 
                    data_used[i] <= 'sd0;
                else begin
                    case(data_type)
                        3'b000: // uint8
                            data_used[i] <= {{(MAX_WD-8){1'b0}},data_masked[i*8+7,i*8]};
                        3'b001: // uint16
                            data_used[i] <= {{(MAX_WD-16){1'b0}},data_masked[i*16+15,i*16]};
                        3'b010: // uint32
                            data_used[i] <= {{(MAX_WD-32){1'b0}},data_masked[i*32+31,i*32]};
                        3'b100: // int8
                            data_used[i] <= {{(MAX_WD-8){data_masked[i*8+7]}},data_masked[i*8+7,i*8]};
                        3'b101: // int16
                            data_used[i] <= {{(MAX_WD-16){data_masked[i*16+15]}},data_masked[i*16+15,i*16]};
                        3'b110: // int32
                            data_used[i] <= {{(MAX_WD-32){data_masked[i*32+31]}},data_masked[i*32+31,i*32]};
                        default:
                            data_used[i] <= {{(MAX_WD-8){1'b0}},data_masked[i*8+7,i*8]};
                    endcase
                end
            end
        end
    // implementing MULT // 
    assign weight_used[i] = pingpong_flag?  RWB[i] : RWA[i];
    mult_int32_unit mult32_inst(.mult_a(data_used[i]), .mult_b(weight_used[i]), .mult_out(mult_out[i]));
    end
endgenerate
// ADD // 
adder_32_uint #(.IN_WD(MAX_WD*2), .OUT_WD(OUT_WD))
    add32_inst(
    .ain_0(mult_out[0])  ,    .ain_1(mult_out[1])  ,    .ain_2(mult_out[2])  ,    .ain_3(mult_out[3])  ,
    .ain_4(mult_out[4])  ,    .ain_5(mult_out[5])  ,    .ain_6(mult_out[6])  ,    .ain_7(mult_out[7])  ,
    .ain_8(mult_out[8])  ,    .ain_9(mult_out[9])  ,    .ain_10(mult_out[10]),    .ain_11(mult_out[11]),
    .ain_12(mult_out[12]),    .ain_13(mult_out[13]),    .ain_14(mult_out[14]),    .ain_15(mult_out[15]),
    .ain_16(mult_out[16]),    .ain_17(mult_out[17]),    .ain_18(mult_out[18]),    .ain_19(mult_out[19]),
    .ain_20(mult_out[20]),    .ain_21(mult_out[21]),    .ain_22(mult_out[22]),    .ain_23(mult_out[23]),
    .ain_24(mult_out[24]),    .ain_25(mult_out[25]),    .ain_26(mult_out[26]),    .ain_27(mult_out[27]),
    .ain_28(mult_out[28]),    .ain_29(mult_out[29]),    .ain_30(mult_out[30]),    .ain_31(mult_out[31]),
    .sum_out(sum_out)
);
// OUTPUT //
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        {data_out_vld, data_in_vld_d1} <= 2'd0;
    else 
        {data_out_vld, data_in_vld_d1} <= {data_in_vld_d1, data_in_vld};
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        data_out <= 'sd0;
    else if(data_in_vld_d1)
        data_out <= sum_out;
end
endmodule