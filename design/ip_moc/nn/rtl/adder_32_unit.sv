module adder_32_uint #(
    parameter IN_WD  = 64,
    parameter OUT_WD = 12
)(
    input signed [IN_WD-1:0]            ain_0   ,
    input signed [IN_WD-1:0]            ain_1   ,
    input signed [IN_WD-1:0]            ain_2   ,
    input signed [IN_WD-1:0]            ain_3   ,
    input signed [IN_WD-1:0]            ain_4   ,
    input signed [IN_WD-1:0]            ain_5   ,
    input signed [IN_WD-1:0]            ain_6   ,
    input signed [IN_WD-1:0]            ain_7   ,
    input signed [IN_WD-1:0]            ain_8   ,
    input signed [IN_WD-1:0]            ain_9   ,
    input signed [IN_WD-1:0]            ain_10  ,
    input signed [IN_WD-1:0]            ain_11  ,
    input signed [IN_WD-1:0]            ain_12  ,
    input signed [IN_WD-1:0]            ain_13  ,
    input signed [IN_WD-1:0]            ain_14  ,
    input signed [IN_WD-1:0]            ain_15  ,
    input signed [IN_WD-1:0]            ain_16  ,
    input signed [IN_WD-1:0]            ain_17  ,
    input signed [IN_WD-1:0]            ain_18  ,
    input signed [IN_WD-1:0]            ain_19  ,    
    input signed [IN_WD-1:0]            ain_20  ,
    input signed [IN_WD-1:0]            ain_21  ,
    input signed [IN_WD-1:0]            ain_22  ,
    input signed [IN_WD-1:0]            ain_23  ,
    input signed [IN_WD-1:0]            ain_24  ,
    input signed [IN_WD-1:0]            ain_25  ,
    input signed [IN_WD-1:0]            ain_26  ,
    input signed [IN_WD-1:0]            ain_27  ,
    input signed [IN_WD-1:0]            ain_28  ,
    input signed [IN_WD-1:0]            ain_29  ,    
    input signed [IN_WD-1:0]            ain_30  ,
    input signed [IN_WD-1:0]            ain_31  ,
    output logic signed [OUT_WD-1:0]    sum_out
);
assign sum_out = 
                    ain_0   +    ain_1   +    ain_2   +    .ain_3   +
                    ain_4   +    ain_5   +    ain_6   +    .ain_7   +
                    ain_8   +    ain_9   +    ain_10  +    .ain_11  +
                    ain_12  +    ain_13  +    ain_14  +    .ain_15  +
                    ain_16  +    ain_17  +    ain_18  +    .ain_19  +
                    ain_20  +    ain_21  +    ain_22  +    .ain_23  +
                    ain_24  +    ain_25  +    ain_26  +    .ain_27  +
                    ain_28  +    ain_29  +    ain_30  +    .ain_31  ;
                    
endmodule