module lzc(
    input               mode        ,
    input               lead        ,
    input               trail       ,
    input [15:0]        data_in     ,
    output logic [4:0]  cnt_out
);

logic [4:0]     tmp_cnt_out;
logic [15:0]    data_s;
logic [15:0]    datain_reverse;
logic [15:0]    stage_node_0;
logic [7: 0]    stage_node_1;
logic [3: 0]    stage_node_2;
logic [1: 0]    stage_node_3;
logic [3: 0]    stage_index1_0;
logic [3: 0]    stage_index1_1;
logic [3: 0]    stage_index1_2;
logic [3: 0]    stage_index1_3;
logic [3: 0]    stage_index1_4;
logic [3: 0]    stage_index1_5;
logic [3: 0]    stage_index1_6;
logic [3: 0]    stage_index1_7;
logic [3: 0]    stage_index2_0;
logic [3: 0]    stage_index2_1;
logic [3: 0]    stage_index2_2;
logic [3: 0]    stage_index2_3;
logic [3: 0]    stage_index3_0;
logic [3: 0]    stage_index3_1;
logic [3: 0]    stage_index4_0;
logic           empty;
logic [3: 0]    out_remap;

assign tmp_cnt_out = {1'b0, out_remap};
assign datain_reverse = {data_in[0],data_in[1],data_in[2],data_in[3],data_in[4],data_in[5],data_in[6],data_in[7],data_in[8],data_in[9],data_in[10],data_in[11],data_in[12],data_in[13],data_in[14],data_in[15]};

always@(*) begin
    data_s = 16'h0;
    if(mode) begin
        if(lead)
            data_s = datain_reverse;
        else if(trail)
            data_s = data_in;
    end
    else begin
        if(lead)
            data_s = ~datain_reverse;
        else if(trail)
            data_s = ~data_in;
    end    
end

assign stage_node_0 = data_s;

always@(*) begin
    stage_node_1[0] = (stage_node_0[0]  || stage_node_0[1]);
    stage_node_1[1] = (stage_node_0[2]  || stage_node_0[3]);
    stage_node_1[2] = (stage_node_0[4]  || stage_node_0[5]);
    stage_node_1[3] = (stage_node_0[6]  || stage_node_0[7]);
    stage_node_1[4] = (stage_node_0[8]  || stage_node_0[9]);
    stage_node_1[5] = (stage_node_0[10] || stage_node_0[11]);
    stage_node_1[6] = (stage_node_0[12] || stage_node_0[13]);
    stage_node_1[7] = (stage_node_0[14] || stage_node_0[15]);
end

assign stage_index1_0 = (stage_node_0[0]?     4'b0000 : 4'b0001);
assign stage_index1_1 = (stage_node_0[2]?     4'b0010 : 4'b0011);
assign stage_index1_2 = (stage_node_0[4]?     4'b0100 : 4'b0101);
assign stage_index1_3 = (stage_node_0[6]?     4'b0110 : 4'b0111);
assign stage_index1_4 = (stage_node_0[8]?     4'b1000 : 4'b1001);
assign stage_index1_5 = (stage_node_0[10]?    4'b1010 : 4'b1011);
assign stage_index1_6 = (stage_node_0[12]?    4'b1100 : 4'b1101);
assign stage_index1_7 = (stage_node_0[14]?    4'b1110 : 4'b1111);

always@(*) begin
    stage_node_2[0] = (stage_node_1[0]  || stage_node_1[1]);
    stage_node_2[1] = (stage_node_1[2]  || stage_node_1[3]);
    stage_node_2[2] = (stage_node_1[4]  || stage_node_1[5]);
    stage_node_2[3] = (stage_node_1[6]  || stage_node_1[7]);
end

assign stage_index2_0 = (stage_node_1[0]?   stage_index1_0 : stage_index1_1);
assign stage_index2_1 = (stage_node_1[2]?   stage_index1_2 : stage_index1_3);
assign stage_index2_2 = (stage_node_1[4]?   stage_index1_4 : stage_index1_5);
assign stage_index2_3 = (stage_node_1[6]?   stage_index1_6 : stage_index1_7);

assign stage_node_3[0] = (stage_node_2[0] || stage_node_2[1]);
assign stage_node_3[1] = (stage_node_2[2] || stage_node_2[3]);

assign stage_index3_0 = (stage_node_2[0]?   stage_index2_0 : stage_index2_1);
assign stage_index3_1 = (stage_node_2[2]?   stage_index2_2 : stage_index2_3);
assign stage_index4_0 = (stage_node_3[0]?   stage_index3_0 : stage_index3_1);

assign empty = ((lead || trail)?  (!(|data_s)) : 1'b0);

always@(*) begin
    out_remap = 4'b0000;
    if(lead) 
        out_remap = 4'b1111 - stage_index4_0;
    else if(trail)
        out_remap = stage_index4_0;
end

assign cnt_out = (lead && empty)?   5'h10 : tmp_cnt_out;

endmodule