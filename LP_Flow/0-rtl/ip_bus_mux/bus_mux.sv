module bus_mux(
    input           m_wr,
    input           m_rd,
    input [15:0]    m_addr,
    input [15:0]    m_wdata,
    output [15:0]   m_rdata,
    output logic    s0_wr,
    output logic    s0_rd,
    output logic [15:0] s0_addr,
    output logic [15:0] s0_wdata,
    input [15:0]    s0_rdata,
    output logic    s1_wr,
    output logic    s1_rd,
    output logic [15:0] s1_addr,
    output logic [15:0] s1_wdata,
    input [15:0]    s1_rdata,
    output logic    bus_error
);
logic [1:0] sel;
logic s_wr [0:1];
logic s_rd [0:1];
logic [15:0] s_addr [0:1];
logic [15:0] s_wdata [0:1];
logic [15:0] s_rdata [0:1];

assign sel[0] = (m_addr == 16'h100);
assign sel[1] = (m_addr <= 16'h20);

assign m_rdata = sel[0]?    s_rdata[0] : s_rdata[1];

assign bus_error = (m_wr | m_rd) && ~(|sel);

genvar i;
generate
    for(i=0; i<2; i=i+1) begin
        assign s_wr[i] = sel[i]?    m_wr : 1'b0;
        assign s_rd[i] = sel[i]?    m_rd : 1'b0;
        assign s_addr[i] = m_addr;
        assign s_wdata[i] = m_wdata; 
    end
endgenerate

assign s0_wr = s_wr[0];
assign s0_rd = s_rd[0];
assign s0_addr = s_addr[0];
assign s0_wdata = s_wdata[0];
assign s_rdata[0] = s0_rdata;

assign s1_wr = s_wr[1];
assign s1_rd = s_rd[1];
assign s1_addr = s_addr[1];
assign s1_wdata = s_wdata[1];
assign s_rdata[1] = s1_rdata;
endmodule