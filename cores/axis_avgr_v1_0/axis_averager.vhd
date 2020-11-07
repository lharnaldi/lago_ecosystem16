library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_averager is
  generic (
            S_AXIS_TDATA_WIDTH: natural := 128; -- AXIS itf data width
            AXIS_CFG_DWIDTH   : natural := 64;  -- AXIS config itf width
            M_AXIS_TDATA_WIDTH: natural := 32;  -- AXI itf data width
            ADC_DATA_WIDTH    : natural := 16;  -- ADC data width
            MEM_ADDR_WIDTH    : natural := 10;  --Max 2**16
            AVERAGES_WIDTH    : natural := 32   -- Width of the averages counter 2^AVERAGES_WIDTH 
          );
  port ( 
         trig_i            : in std_logic;
         start             : in std_logic;
         done              : out std_logic;

         -- Slave config side
         s_axis_cfg_aclk   : in std_logic;
         s_axis_cfg_aresetn: in std_logic;
         s_axis_cfg_tready : out std_logic;
         s_axis_cfg_tvalid : in std_logic;
         s_axis_cfg_tdata  : in std_logic_vector(AXIS_CFG_DWIDTH-1 downto 0);

         -- Slave data interface
         s_axis_aclk       : in std_logic;
         s_axis_aresetn    : in std_logic;
         s_axis_tready     : out std_logic;
         s_axis_tvalid     : in std_logic;
         s_axis_tdata      : in std_logic_vector(S_AXIS_TDATA_WIDTH-1 downto 0);

         -- Master data interface
         m_axis_aclk       : in std_logic;
         m_axis_aresetn    : in std_logic;
         m_axis_tready     : in std_logic;
         m_axis_tvalid     : out std_logic;
         m_axis_tlast      : out std_logic;
         m_axis_tdata      : out std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0)
       );
end axis_averager;

architecture rtl of axis_averager is

  signal nsamples_s            : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
  signal naverages_s           : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
  signal averages_out_s        : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
  signal done_s                : std_logic;
  signal start_sync            : std_logic;
  signal trig_en_s             : std_logic;
  signal mode_s                : std_logic;

  signal bram_porta_clk_s      : std_logic;
  signal bram_porta_rst_s      : std_logic;
  signal bram_porta_wrdata_s   : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
  signal bram_porta_we_s       : std_logic;
  --signal bram_porta_addr_s   : std_logic_vector(AW-1 downto 0);
  signal bram_porta_addr_s     : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0); --AXI itf
  --signal bram_porta_rddata_s : std_logic_vector(DW-1 downto 0);
  signal bram_porta_rddata_s   : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0); --AXI itf 

  --Register cfg/sts
  signal cfg_gral_reg          : std_logic_vector(AXIS_CFG_DWIDTH-1 downto 0);
  signal cfg_gral_reg_sync     : std_logic_vector(AXIS_CFG_DWIDTH-1 downto 0);
  signal sts_avg_reg           : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
  signal sts_avg_reg_sync      : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);

begin

  --done <= done_s;

  --lets synchronize the start signal
  sync_start: entity work.sync
  port map(
        clk      => s_axis_aclk,
        reset    => s_axis_aresetn,
        in_async => start,
        out_sync => start_sync
      );

  --lets synchronize the done signal
  sync_done: entity work.sync
  port map(
        clk      => s_axis_cfg_aclk,
        reset    => s_axis_cfg_aresetn,
        in_async => done_s,
        out_sync => done
      );

  -- synchronizer 1 
  sync_fifo: entity work.axis_fifo
  generic map(
               AXIS_TDATA_WIDTH => AXIS_CFG_DWIDTH,
               FIFO_DEPTH       => 4
             )
  port map(
            s_axis_aclk       => s_axis_cfg_aclk,
            s_axis_aresetn    => s_axis_cfg_aresetn,
            s_axis_tready     => s_axis_cfg_tready,
            s_axis_tvalid     => s_axis_cfg_tvalid,
            s_axis_tdata      => s_axis_cfg_tdata,

            m_axis_aclk       => s_axis_aclk,
            m_axis_aresetn    => s_axis_aresetn,
            m_axis_tready     => '1',
            m_axis_tvalid     => open,
            m_axis_tdata      => cfg_gral_reg_sync
          );

  mode_s      <= cfg_gral_reg_sync(AXIS_CFG_DWIDTH-1); 
  naverages_s <= '0' & cfg_gral_reg_sync(AXIS_CFG_DWIDTH-2 downto (AXIS_CFG_DWIDTH/2)); 
  nsamples_s  <= cfg_gral_reg_sync((AXIS_CFG_DWIDTH/2)-1 downto 0);  

  --Averager itf
  avg_i : entity work.averager 
  generic map(
               AXIS_TDATA_WIDTH => S_AXIS_TDATA_WIDTH,
               AXI_DATA_WIDTH   => M_AXIS_TDATA_WIDTH,
               ADC_DATA_WIDTH   => ADC_DATA_WIDTH,
               MEM_ADDR_WIDTH   => MEM_ADDR_WIDTH,
               AVERAGES_WIDTH   => AVERAGES_WIDTH
             )
  port map(
            aclk              => s_axis_aclk,
            aresetn           => s_axis_aresetn,
            start_i           => start_sync,
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

  -- determine how many data we need to read from m_axis
  -- it depends of the working MODE
  -- MODE=0 (averaging scope mode) -> so we need to read NSAMPLES samples
  -- MODE=1 (nsamples mode)        -> so we need to read NAVERAGES samples
  rd_cfg_word <= nsamples_s when (mode_s = '0') else 
                 naverages_s;

  --AXIS interface bram reader avg scope and nsamples modes
  axis_bram_itf: entity work.axis_bram_reader
  generic map(
               BRAM_ADDR_WIDTH   => MEM_ADDR_WIDTH,
               BRAM_DATA_WIDTH   => M_AXIS_TDATA_WIDTH,
               AXIS_TDATA_WIDTH  => M_AXIS_TDATA_WIDTH
             )
  port map(
            aclk            => m_axis_aclk,
            aresetn         => m_axis_aresetn,

            cfg_data        => rd_cfg_word,
            sts_data        => open,

            m_axis_tready     => m_axis_tready,
            m_axis_tdata      => m_axis_tdata,
            m_axis_tvalid     => m_axis_tvalid,
            m_axis_tlast      => m_axis_tlast,

            bram_porta_clk    => bram_porta_clk_s,
            bram_porta_rst    => bram_porta_rst_s, 
            bram_porta_addr   => bram_porta_addr_s,
            bram_porta_rddata => bram_porta_rddata_s 
          );

end rtl;
