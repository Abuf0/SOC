// Dead Pixel Correction //
module dpc#(
    parameter DPC_MODE = 0      , // 0: mean  1: gradient
    parameter DW = 16           ,
    parameter H = 1280          ,
    parameter V = 720           ,
    parameter HW = 11           ,
    parameter VW = 10
)(
    input                   clk                 ,
    input                   rstn                ,
    input                   dpc_en              ,
    input [DW-1:0]          thres               ,
    input [DW-1:0]          clip                ,
    input                   pixel_data_in_vld   ,
    input        [DW-1:0]   pixel_data_in       ,
    output logic [DW-1:0]   pixel_data_out      ,
    output logic            pixel_data_out_vld  ,
    output logic            one_frame_done      
);
logic [DW-1:0]shift_reg [0:4*H+4];
logic [DW-1:0] mac_arr[0:8];
logic correct_flag;
logic [DW-1:0] pixel_data_dpc;
logic [DW-1:0] pixel_data_out_pre;

logic [HW-1:0] h_cnt;
logic [VW-1:0] v_cnt;

logic [DW-1:0] abs_delta [0:7];

logic init;
logic tail;

genvar i;
generate
    for(i=0;i<4*H+5;i=i+1) begin: SFT_ARRAY
        if(i==0) begin
            always_ff @( posedge clk or negedge rstn ) begin
                if(~rstn)
                    shift_reg[i] <= 'd0;
                else if(dpc_en && (pixel_data_in_vld | tail))
                    shift_reg[i] <= pixel_data_in;
            end
        end
        //else if(i==2*H+3) begin  // replace dead pixel
        //    always_ff @( posedge clk or negedge rstn ) begin
        //        if(~rstn)
        //            shift_reg[i] <= 'd0;
        //        else if(dpc_en && pixel_data_in_vld) begin
        //            shift_reg[i] <= (pixel_data_dpc > clip)?    clip : pixel_data_dpc;  // clip
        //        end
        //    end
        //end
        else begin
            always_ff @( posedge clk or negedge rstn ) begin
                if(~rstn)
                    shift_reg[i] <= 'd0;
                else if(dpc_en && (pixel_data_in_vld | tail))
                    shift_reg[i] <= shift_reg[i-1];
            end
        end
    end
endgenerate

assign pixel_data_out_pre = (pixel_data_dpc > clip)?    clip : pixel_data_dpc; 

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_data_out <= 'd0;
    else if(dpc_en)
        pixel_data_out <= pixel_data_out_pre;
    else 
        pixel_data_out <= pixel_data_in;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        pixel_data_out_vld <= 1'b0;
    else if(dpc_en)
        //pixel_data_out_vld <= pixel_data_in_vld_ff[4*H+3];
        pixel_data_out_vld <= (~init && pixel_data_in_vld) | tail;
    else 
        pixel_data_out_vld <= pixel_data_in_vld;
end

// assuming pixel_data_in_vld always = 1

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        h_cnt <= 'd0;
    else if(init && v_cnt==2 && h_cnt==2)
        h_cnt <= 'd0;
    else if(dpc_en && (pixel_data_in_vld | tail))
        h_cnt <= (h_cnt==H-1)?  'd0:(h_cnt+1'b1);
end
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)
        v_cnt <= 'd0;
    else if(init && v_cnt==2 && h_cnt==2)
        v_cnt <= 'd0;
    else if(dpc_en && (pixel_data_in_vld | tail) && h_cnt==H-1)
        v_cnt <= (v_cnt==V-1)?  'd0:(v_cnt+1'b1);
end
   
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)   
        init <= 1'b1;
    else if(init && v_cnt==2 && h_cnt==2)
        init <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)   
        tail <= 1'b0;
    else if(v_cnt==V-3 && h_cnt==H-2)
        tail <= 1'b1;
    else if(v_cnt==V-1 && h_cnt==H-1)
        tail <= 1'b0;
end

always_ff@(posedge clk or negedge rstn) begin
    if(~rstn)   
        one_frame_done <= 1'b0;
    else if(v_cnt==V-1 && h_cnt==H-1)
        one_frame_done <= 1'b1;
    else if(one_frame_done)
        one_frame_done <= 1'b0;
end

assign mac_arr[0] = (v_cnt > 'd1 && h_cnt > 'd1)? shift_reg[4*H+4]          : 'd0 ;
assign mac_arr[1] = (v_cnt > 'd1)?                shift_reg[4*H+2]          : 'd0 ;
assign mac_arr[2] = (v_cnt > 'd1 && h_cnt < H-2)? shift_reg[4*H]            : 'd0 ;
assign mac_arr[3] = (h_cnt > 'd1)?                shift_reg[2*H+4]          : 'd0 ;
assign mac_arr[4] =                               shift_reg[2*H+2]                ;
assign mac_arr[5] = (h_cnt < H-2)?                shift_reg[2*H]            : 'd0 ;
assign mac_arr[6] = (v_cnt < V-2 && h_cnt > 'd1)? shift_reg[4]              : 'd0 ;
assign mac_arr[7] = (v_cnt < V-2)?                shift_reg[2]              : 'd0 ;
assign mac_arr[8] = (v_cnt < V-2 && h_cnt < H-2)? shift_reg[0]              : 'd0 ;

assign abs_delta[0] = (mac_arr[0] > mac_arr[4])?    (mac_arr[0]-mac_arr[4]) : (mac_arr[4]-mac_arr[0]) ;
assign abs_delta[1] = (mac_arr[1] > mac_arr[4])?    (mac_arr[1]-mac_arr[4]) : (mac_arr[4]-mac_arr[1]) ;
assign abs_delta[2] = (mac_arr[2] > mac_arr[4])?    (mac_arr[2]-mac_arr[4]) : (mac_arr[4]-mac_arr[2]) ;
assign abs_delta[3] = (mac_arr[3] > mac_arr[4])?    (mac_arr[3]-mac_arr[4]) : (mac_arr[4]-mac_arr[3]) ;
assign abs_delta[4] = (mac_arr[5] > mac_arr[4])?    (mac_arr[5]-mac_arr[4]) : (mac_arr[4]-mac_arr[5]) ;
assign abs_delta[5] = (mac_arr[6] > mac_arr[4])?    (mac_arr[6]-mac_arr[4]) : (mac_arr[4]-mac_arr[6]) ;
assign abs_delta[6] = (mac_arr[7] > mac_arr[4])?    (mac_arr[7]-mac_arr[4]) : (mac_arr[4]-mac_arr[7]) ;
assign abs_delta[7] = (mac_arr[8] > mac_arr[4])?    (mac_arr[8]-mac_arr[4]) : (mac_arr[4]-mac_arr[8]) ;


//assign correct_flag = dpc_en?  ($abs(mac_arr[0]-mac_arr[4]) > thres && $abs(mac_arr[1]-mac_arr[4]) > thres && $abs(mac_arr[2]-mac_arr[4]) > thres &&
//                                $abs(mac_arr[3]-mac_arr[4]) > thres && $abs(mac_arr[5]-mac_arr[4]) > thres &&
//                                $abs(mac_arr[6]-mac_arr[4]) > thres && $abs(mac_arr[7]-mac_arr[4]) > thres && $abs(mac_arr[8]-mac_arr[4]) > thres) : 0;

assign correct_flag = dpc_en?  ( (abs_delta[0] > thres) && (abs_delta[1] > thres) && (abs_delta[2] > thres) &&
                                 (abs_delta[3] > thres) && (abs_delta[4] > thres) &&
                                 (abs_delta[5] > thres) && (abs_delta[6] > thres) && (abs_delta[7] > thres) ) : 0;
assign pixel_data_dpc = correct_flag?   ((mac_arr[1] + mac_arr[7] + mac_arr[3] + mac_arr[5])>>2) : mac_arr[4];


`ifdef SIM
integer file;
integer file_p;
integer file_in;
initial begin
   file = $fopen("./dpc_result.csv","w+");  // 初始化文件
   file_p = $fopen("./dpc_p_data.csv","w+"); 
   file_in = $fopen("./raw_data.csv","w+"); 
end

always @(posedge clk) begin
    if (pixel_data_out_vld) begin
        $fwrite(file,"(%d,%d):%d\n",v_cnt,h_cnt, pixel_data_out);
    end
//     else begin
//         $fclose(file);   // 这里一定要写，关闭文件读写
//     end
end
always @(posedge clk) begin
    if (pixel_data_in_vld) begin
        $fwrite(file_in,"%d\n",pixel_data_in);
    end
end
always @(negedge clk) begin
    if ((pixel_data_in_vld && ~init) | tail) begin
        $fwrite(file_p,"(%d,%d):%d\t%d,%d\n",v_cnt,h_cnt,pixel_data_dpc,correct_flag,mac_arr[4]);
    end
end
`endif

endmodule