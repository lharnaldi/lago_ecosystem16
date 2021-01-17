library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_averager is
  generic (
            S_AXIS_TDATA_WIDTH: natural := 128; -- AXIS itf data width
            M_AXIS_TDATA_WIDTH: natural := 32;  -- AXI itf data width
            ADC_DATA_WIDTH    : natural := 16;  -- ADC data width
            MEM_AWIDTH        : natural := 10;  -- MEM addr width
            MEM_DEPTH         : natural := 1024 --Max 2**16
          );
  port ( 
         start             : in std_logic;
         --restart         : in std_logic;
         trig_i            : in std_logic;
         send_data         : in std_logic;
         done              : out std_logic;
         READOUT_State_Mon : out std_logic_vector(2 downto 0);
         mode_out          : out std_logic;
         --debug sync to s_axis_clk
         start_sync_o      : out std_logic;
         trig_sync_o       : out std_logic;
         done_o            : out std_logic;
         restart_o         : out std_logic;
         send_data_o       : out std_logic;
         averages_out_o    : out std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
         --asy_addra_o       : out std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
         --asy_wea_o         : out std_logic;
         tdp_ena_o         : out std_logic;
         op_we_o           : out std_logic;
         op_addr_o         : out std_logic_vector(MEM_AWIDTH-1 downto 0); 
         op_din_o          : out std_logic_vector(2*ADC_DATA_WIDTH-1 downto 0);

         --nsamples_o        : out std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
         --naverages_o       : out std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);

         --debug sync to m_axis_clk
         sts_data_o        : out std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
         cfg_data_o        : out std_logic_vector(MEM_AWIDTH-1 downto 0);


         -- Slave config side
         s_axis_cfg_aclk   : in std_logic;
         s_axis_cfg_aresetn: in std_logic;
         s_axis_cfg_tready : out std_logic;
         s_axis_cfg_tvalid : in std_logic;
         s_axis_cfg_tdata  : in std_logic_vector(64-1 downto 0);

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
         m_axis_tkeep      : out std_logic_vector(4-1 downto 0);
         m_axis_tdata      : out std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0)
       );
end axis_averager;

architecture rtl of axis_averager is

  signal nsamples_s  : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
  signal naverages_s : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
  signal averages_out_s        : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
  signal done_s                : std_logic;
  signal done_sync             : std_logic;
  signal send_sync             : std_logic;
  signal start_sync            : std_logic;
  signal trig_sync             : std_logic;
  signal trig_os               : std_logic; --one shot trigger
  signal restart_s             : std_logic;
  signal restart_sync          : std_logic;
  signal trig_en_s             : std_logic;
  signal mode_s                : std_logic;
  signal cfg_tvalid            : std_logic;

  signal bram_porta_clk_s      : std_logic;
  --  signal bram_porta_rst_s      : std_logic;
  signal bram_porta_wrdata_s   : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0);
  signal bram_porta_we_s       : std_logic;
  signal bram_porta_addr_s     : std_logic_vector(MEM_AWIDTH-1 downto 0); --AXI itf
  signal bram_porta_rddata_s   : std_logic_vector(M_AXIS_TDATA_WIDTH-1 downto 0); --AXI itf 

  --Register cfg/sts
  signal cfg_gral_reg          : std_logic_vector(64-1 downto 0);
  signal cfg_gral_reg_sync     : std_logic_vector(64-1 downto 0);
  signal rd_cfg_word           : std_logic_vector(MEM_AWIDTH-1 downto 0);
  --signal asy_addra_o_s         : std_logic_vector(MEM_AWIDTH-1 downto 0);

begin

  --done <= done_s;
  --asy_addra_o <= std_logic_vector(resize(unsigned(asy_addra_o_s),asy_addra_o'length));

  --lets synchronize the start signal
  sync_start: entity work.sync
  port map(
            clk      => s_axis_aclk,
            reset    => s_axis_aresetn,
            in_async => start,
            out_sync => start_sync
          );
  start_sync_o <= start_sync;

  --lets synchronize the trigger signal
  sync_trig: entity work.sync
  port map(
            clk      => s_axis_aclk,
            reset    => s_axis_aresetn,
            in_async => trig_i,
            out_sync => trig_sync
          );

  os_trig: entity work.edge_det
  port map(
            aclk     => s_axis_aclk,
            areset   => s_axis_aresetn,
            sig_i    => trig_sync,
            sig_o    => trig_os
          );

  trig_sync_o <= trig_os;


  --lets synchronize the done signal
  sync_done: entity work.sync
  port map(
            clk      => s_axis_cfg_aclk,
            reset    => s_axis_cfg_aresetn,
            in_async => done_s,
            out_sync => done
          );
  done_o <= done_s;

  -- synchronizer 1 
  sync_fifo: entity work.axis_fifo
  generic map(
               AXIS_TDATA_WIDTH => 64,
               AWIDTH           => 4,
               FIFO_DEPTH       => 16
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

  mode_s      <= cfg_gral_reg_sync(64-1); 
  mode_out    <= cfg_gral_reg_sync(64-1); 
  naverages_s <= '0' & cfg_gral_reg_sync(64-2 downto (64/2)); 
  nsamples_s  <= cfg_gral_reg_sync((64/2)-1 downto 0);  
  --process(s_axis_aclk)
  --begin
  --  if rising_edge(s_axis_aclk) then
  --    if s_axis_aresetn = '0' then
  --      mode_reg      <= '0';
  --      nsamples_reg  <= (others => '0');
  --      naverages_reg <= (others => '0');
  --    else
  --      mode_reg      <= mode_next;
  --      nsamples_reg  <= nsamples_next;
  --      naverages_reg <= naverages_next;
  --    end if;
  --  end if;
  --end process;

  --mode_next <= cfg_gral_reg_sync(64-1) when cfg_tvalid = '1' else
  --             mode_reg; 
  --mode_out  <= mode_reg; 
  --naverages_next <= '0' & cfg_gral_reg_sync(64-2 downto (64/2)) when cfg_tvalid = '1' else
  --                  naverages_reg; 
  ----naverages_o    <= naverages_reg; 
  --nsamples_next  <= cfg_gral_reg_sync((64/2)-1 downto 0) when cfg_tvalid = '1' else
  --                  nsamples_reg;  
  --nsamples_o     <= nsamples_reg;  

  --lets synchronize the restart signal
  sync_restart: entity work.sync
  port map(
            clk      => s_axis_aclk,
            reset    => s_axis_aresetn,
            in_async => restart_s,
            out_sync => restart_sync
          );

  restart_o <= restart_sync;

  --Averager itf
  avg_i : entity work.averager 
  generic map(
               IN_DATA_WIDTH  => S_AXIS_TDATA_WIDTH,
               OUT_DATA_WIDTH => M_AXIS_TDATA_WIDTH,
               ADC_DATA_WIDTH => ADC_DATA_WIDTH,
               MEM_AWIDTH     => MEM_AWIDTH,
               MEM_DEPTH      => MEM_DEPTH
             )
  port map(
            aclk              => s_axis_aclk,
            aresetn           => s_axis_aresetn,
            start             => start_sync,
            restart           => restart_sync,
            mode              => mode_s, --0- (default) avg scope, 1-avg nsamples to one value
            trig_i            => trig_os,
            READOUT_State_Mon => READOUT_State_Mon,
            nsamples          => nsamples_s,
            naverages         => naverages_s,
            done              => done_s,
            averages_out      => averages_out_o,
            tdp_ena_o         => tdp_ena_o,
            op_we_o           => op_we_o,
            op_addr_o         => op_addr_o, 
            op_din_o          => op_din_o,

            --var_o             => var_o,

            bram_porta_clk    => bram_porta_clk_s,
            --bram_porta_rst    => bram_porta_rst_s,
            --bram_porta_wrdata => (others => '0'),
            --bram_porta_we     => '0',
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
  rd_cfg_word <= std_logic_vector(resize(unsigned(nsamples_s),rd_cfg_word'length)) when (mode_s = '0') else 
                 std_logic_vector(resize(unsigned(naverages_s),rd_cfg_word'length));

  --lets synchronize the done signal
  sync_mdone: entity work.sync
  port map(
            clk      => m_axis_aclk,
            reset    => m_axis_aresetn,
            in_async => done_s,
            out_sync => done_sync
          );

  --lets synchronize the send_data signal
  sync_send: entity work.sync
  port map(
            clk      => m_axis_aclk,
            reset    => m_axis_aresetn,
            in_async => send_data,
            out_sync => send_sync
          );

  --lets synchronize the send_data signal for debug
  sync_send2: entity work.sync
  port map(
            clk      => s_axis_aclk,
            reset    => s_axis_aresetn,
            in_async => send_data,
            out_sync => send_data_o
          );

  --AXIS interface bram reader avg scope and nsamples modes
  axis_bram_itf: entity work.axis_bram_reader
  generic map(
               BRAM_DEPTH       => MEM_DEPTH,
               BRAM_AWIDTH      => MEM_AWIDTH,
               AXIS_TDATA_WIDTH => M_AXIS_TDATA_WIDTH
             )
  port map(
            aclk            => m_axis_aclk,
            aresetn         => m_axis_aresetn,

            cfg_data_o      => cfg_data_o,
            cfg_data        => rd_cfg_word,
            sts_data        => sts_data_o,
            done            => done_sync,
            send            => send_sync,
            restart_o       => restart_s,

            m_axis_tready     => m_axis_tready,
            m_axis_tdata      => m_axis_tdata,
            m_axis_tvalid     => m_axis_tvalid,
            m_axis_tlast      => m_axis_tlast,
            m_axis_tkeep      => m_axis_tkeep,

            bram_porta_clk    => bram_porta_clk_s,
            -- bram_porta_rst    => bram_porta_rst_s, 
            bram_porta_addr   => bram_porta_addr_s,
            bram_porta_rddata => bram_porta_rddata_s 
          );

end rtl;
