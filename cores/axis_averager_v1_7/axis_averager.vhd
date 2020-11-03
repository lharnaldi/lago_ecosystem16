library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_averager is
  generic (
            AXIS_TDATA_WIDTH: natural := 128; -- AXIS itf data width
            AXI_DATA_WIDTH  : natural := 32;  -- AXI itf data width
            ADC_DATA_WIDTH  : natural := 16;  -- ADC data width
            MEM_ADDR_WIDTH  : natural := 10;  --Max 2**16
            AVERAGES_WIDTH  : natural := 32   -- Width of the averages counter 2^AVERAGES_WIDTH 
          );
  port ( 
         -- AXI 00 INTERFACE CFG/STS REGISTERS
         s00_axi_aclk     : in std_logic;
         s00_axi_aresetn  : in std_logic;
         s00_axi_awaddr   : in std_logic_vector(6-1 downto 0); --6 here is for  16 registers (up to 32) 
         s00_axi_awprot   : in std_logic_vector(2 downto 0);
         s00_axi_awvalid  : in std_logic;                                   
         s00_axi_awready  : out std_logic;                                 
         s00_axi_wdata    : in std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
         s00_axi_wstrb    : in std_logic_vector(AXI_DATA_WIDTH/8-1 downto 0);
         s00_axi_wvalid   : in std_logic;                                   
         s00_axi_wready   : out std_logic;                                 
         s00_axi_bresp    : out std_logic_vector(1 downto 0);             
         s00_axi_bvalid   : out std_logic;                               
         s00_axi_bready   : in std_logic;                               
         s00_axi_araddr   : in std_logic_vector(6-1 downto 0); --6 here is for  16 registers (up to 32)
         s00_axi_arprot   : in std_logic_vector(2 downto 0);
         s00_axi_arvalid  : in std_logic;                                  
         s00_axi_arready  : out std_logic;                                
         s00_axi_rdata    : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0); 
         s00_axi_rresp    : out std_logic_vector(1 downto 0);               
         s00_axi_rvalid   : out std_logic;                                 
         s00_axi_rready   : in std_logic;                                   

         -- AXI 01 INTERFACE BRAM READER AVERAGER SCOPE/NSAMPLES MODES DMA
         s01_axi_aclk    : in std_logic;
         s01_axi_aresetn : in std_logic;
         s01_axi_awaddr  : in  std_logic_vector(16-1 downto 0); 
         s01_axi_awvalid : in  std_logic;                                  
         s01_axi_awready : out std_logic;                                 
         s01_axi_wdata   : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
         s01_axi_wvalid  : in  std_logic;                                 
         s01_axi_wready  : out std_logic;                                
         s01_axi_bresp   : out std_logic_vector(1 downto 0);             
         s01_axi_bvalid  : out std_logic;                               
         s01_axi_bready  : in  std_logic;                              
         s01_axi_araddr  : in  std_logic_vector(16-1 downto 0);
         s01_axi_arvalid : in  std_logic;                                 
         s01_axi_arready : out std_logic;                                
         s01_axi_rdata   : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
         s01_axi_rresp   : out std_logic_vector(1 downto 0);              
         s01_axi_rvalid  : out std_logic;                                 
         s01_axi_rready  : in  std_logic;                                

         trig_i          : in std_logic;
         done            : out std_logic;

         -- AXIS INTERFACE
         s_axis_aclk     : in std_logic;
         s_axis_aresetn  : in std_logic;
         s_axis_tready   : out std_logic;
         s_axis_tvalid   : in std_logic;
         s_axis_tdata    : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
       );
end axis_averager;

architecture rtl of axis_averager is

signal nsamples_s            : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal naverages_s           : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal averages_out_s        : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal done_s                : std_logic;
signal start_s               : std_logic;
signal trig_en_s             : std_logic;
signal mode_s                : std_logic;

signal bram_porta_clk_s      : std_logic;
signal bram_porta_rst_s      : std_logic;
signal bram_porta_wrdata_s   : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal bram_porta_we_s       : std_logic;
--signal bram_porta_addr_s   : std_logic_vector(AW-1 downto 0);
signal bram_porta_addr_s     : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0); --AXI itf
--signal bram_porta_rddata_s : std_logic_vector(DW-1 downto 0);
signal bram_porta_rddata_s   : std_logic_vector(AXI_DATA_WIDTH-1 downto 0); --AXI itf 

--Register cfg/sts
signal sts_gral_reg          : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal sts_gral_reg_sync     : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal cfg_gral_reg          : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal cfg_gral_reg_sync     : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal cfg_nsamples_reg      : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal cfg_nsamples_reg_sync : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal cfg_naverages_reg     : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal cfg_naverages_reg_sync: std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal sts_avg_reg           : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal sts_avg_reg_sync      : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

begin

  done <= done_s;

  --AXI 00 interface config/status registers
  cfg_sts_i : entity work.axi_lite_slv
  generic map(
               DATA_WIDTH  => AXI_DATA_WIDTH,
               ADDR_WIDTH  => 6
             )
  port map(
            STS_GRAL_REG      => sts_gral_reg_sync,     
            CFG_GRAL_REG      => cfg_gral_reg,     
            CFG_NSAMPLES_REG  => cfg_nsamples_reg,
            CFG_NAVERAGES_REG => cfg_naverages_reg,
            STS_AVG_REG       => sts_avg_reg_sync,

            aclk    => s00_axi_aclk,   
            aresetn => s00_axi_aresetn,
            awaddr  => s00_axi_awaddr, 
            awprot  => s00_axi_awprot,
            awvalid => s00_axi_awvalid,
            awready => s00_axi_awready,
            wdata   => s00_axi_wdata,  
            wstrb   => s00_axi_wstrb,  
            wvalid  => s00_axi_wvalid, 
            wready  => s00_axi_wready, 
            bresp   => s00_axi_bresp,  
            bvalid  => s00_axi_bvalid, 
            bready  => s00_axi_bready, 
            araddr  => s00_axi_araddr, 
            arprot  => s00_axi_arprot,
            arvalid => s00_axi_arvalid,
            arready => s00_axi_arready,
            rdata   => s00_axi_rdata,  
            rresp   => s00_axi_rresp,  
            rvalid  => s00_axi_rvalid, 
            rready  => s00_axi_rready 
          );

  -- synchronizer 0 from PL to PS clk -> PS
  sync0_i: entity work.shift_register
  generic map(
           SR_WIDTH => AXI_DATA_WIDTH,
           SR_DEPTH => 2
         )
  port map
  (
         aclk    => s00_axi_aclk,
         aresetn => s00_axi_aresetn,
         en      => '1',
         data_i  => sts_gral_reg,
         data_o  => sts_gral_reg_sync
         );
  --Status
  --sts_gral_reg <= ((AXI_DATA_WIDTH-1) downto 4 => '0') & done_s & rst_avg_s & trig_en_s & mode_s;
  sts_gral_reg <= ((AXI_DATA_WIDTH-1) downto 1 => '0') & done_s;

  -- synchronizer 1 from PL to PS clk -> PS
  sync1_i: entity work.shift_register
  generic map(
           SR_WIDTH => AXI_DATA_WIDTH,
           SR_DEPTH => 2
         )
  port map
  (
         aclk    => s00_axi_aclk,
         aresetn => s00_axi_aresetn,
         en      => '1',
         data_i  => sts_avg_reg,
         data_o  => sts_avg_reg_sync
         );
  sts_avg_reg <= averages_out_s;


  -- synchronizer 2 from PS to PL clk -> PL
  sync2_i: entity work.shift_register
  generic map(
           SR_WIDTH => AXI_DATA_WIDTH,
           SR_DEPTH => 2
         )
  port map
  (
         aclk    => s_axis_aclk,
         aresetn => s_axis_aresetn,
         en      => '1',
         data_i  => cfg_gral_reg,
         data_o  => cfg_gral_reg_sync
         );
  start_s    <= cfg_gral_reg_sync(1);   -- OFFSET=4
  mode_s     <= cfg_gral_reg_sync(2);   -- OFFSET=4
  trig_en_s  <= cfg_gral_reg_sync(3);   -- OFFSET=4

  -- synchronizer 3 from PS to PL clk -> PL
  sync3_i: entity work.shift_register
  generic map(
           SR_WIDTH => AXI_DATA_WIDTH,
           SR_DEPTH => 2
         )
  port map
  (
         aclk    => s_axis_aclk,
         aresetn => s_axis_aresetn,
         en      => '1',
         data_i  => cfg_naverages_reg,
         data_o  => cfg_naverages_reg_sync
         );
  naverages_s <= cfg_naverages_reg_sync; -- OFFSET=8

  -- synchronizer 3 from PS to PL clk -> PL
  sync4_i: entity work.shift_register
  generic map(
           SR_WIDTH => AXI_DATA_WIDTH,
           SR_DEPTH => 2
         )
  port map
  (
         aclk    => s_axis_aclk,
         aresetn => s_axis_aresetn,
         en      => '1',
         data_i  => cfg_nsamples_reg,
         data_o  => cfg_nsamples_reg_sync
         );
  nsamples_s  <= cfg_nsamples_reg_sync;  -- OFFSET=12


  --AXI 01 interface bram reader avg scope and nsamples modes
  bram_rd00_i : entity work.axi_bram_reader
  generic map
  (
    AXI_DATA_WIDTH => AXI_DATA_WIDTH,
    AXI_ADDR_WIDTH => 16, --AXI_ADDR_WIDTH,
    BRAM_ADDR_WIDTH=> MEM_ADDR_WIDTH,
    BRAM_DATA_WIDTH=> AXI_DATA_WIDTH --32
  )
  port map
  (
            aclk          => s01_axi_aclk,   
            aresetn       => s01_axi_aresetn,
            s_axi_awaddr  => s01_axi_awaddr, 
            s_axi_awvalid => s01_axi_awvalid,
            s_axi_awready => s01_axi_awready,
            s_axi_wdata   => s01_axi_wdata,  
            s_axi_wvalid  => s01_axi_wvalid, 
            s_axi_wready  => s01_axi_wready, 
            s_axi_bresp   => s01_axi_bresp,  
            s_axi_bvalid  => s01_axi_bvalid, 
            s_axi_bready  => s01_axi_bready, 
            s_axi_araddr  => s01_axi_araddr, 
            s_axi_arvalid => s01_axi_arvalid,
            s_axi_arready => s01_axi_arready,
            s_axi_rdata   => s01_axi_rdata,  
            s_axi_rresp   => s01_axi_rresp,  
            s_axi_rvalid  => s01_axi_rvalid, 
            s_axi_rready  => s01_axi_rready, 

            -- BRAM port
            bram_porta_clk    => bram_porta_clk_s,
            bram_porta_rst    => bram_porta_rst_s,
            bram_porta_addr   => bram_porta_addr_s,
            bram_porta_rddata => bram_porta_rddata_s 
          );

  --Averager itf
  avg_i : entity work.averager 
  generic map
  (
            AXIS_TDATA_WIDTH => AXIS_TDATA_WIDTH,
            AXI_DATA_WIDTH   => AXI_DATA_WIDTH,
            ADC_DATA_WIDTH   => ADC_DATA_WIDTH,
            MEM_ADDR_WIDTH   => MEM_ADDR_WIDTH
          )
  port map
  (
         aclk              => s_axis_aclk,
         aresetn           => s_axis_aresetn,
         start_i           => start_s,
         trig_en           => trig_en_s,
         mode              => mode_s, --0- (default) avg scope, 1-avg nsamples to one value
         trig_i            => trig_i,
         nsamples          => nsamples_s,
         naverages         => naverages_s,
         finished          => done_s,
         averages_out      => averages_out_s,

         bram_porta_clk    => bram_porta_clk_s,
         bram_porta_rst    => bram_porta_rst_s,
         bram_porta_wrdata => (others => '0'),
         bram_porta_we     => '0',
         bram_porta_addr   => bram_porta_addr_s,
         bram_porta_rddata => bram_porta_rddata_s, 

         s_axis_tready     => s_axis_tready,
         s_axis_tvalid     => s_axis_tvalid,
         s_axis_tdata      => s_axis_tdata
       );

end rtl;
