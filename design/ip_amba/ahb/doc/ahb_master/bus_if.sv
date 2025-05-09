interface m_if(input bit HCLK, input bit HRESETn);
    //input for AHB master
    logic           HGRANT;
    logic           HREADY;
    logic [1:0]     HRESP;
    logic [31:0]    HRDATA;
    //output for AHB master
    logic           HBUSREQ;
    logic           HLOCK;
    logic [1:0]     HTRANS;
    logic [31:0]    HADDR;
    logic           HWRITE;
    logic [2:0]     HSIZE;
    logic [2:0]     HBURST;
    logic [3:0]     HPROT;
    logic [31:0]    HWDATA;

endinterface : m_if

interface s_if(input bit HCLK, input bit HRESETn);
    //input for AHB slave
    logic           HSEL;
    logic [31:0]    HADDR;
    logic [31:0]    HWDATA;
    logic           HWRITE;
    logic [1:0]     HTRANS;
    logic [2:0]     HSIZE;
    logic [2:0]     HBURST;
    logic [3:0]     HMASTER;
    logic [3:0]     HPROT;
    logic           HMASTERLOCK;
    //output for AHB slave
    logic           HREADY;
    logic [1:0]     HRESP;
    logic [31:0]    HRDATA;
    logic [15:0]    HSPLIT;
endinterface :s_if
