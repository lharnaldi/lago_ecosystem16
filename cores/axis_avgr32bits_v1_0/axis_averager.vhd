library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_averager is
  generic (
            S_AXIS_DWIDTH : natural := 128; -- AXIS itf data width
            M_AXIS_DWIDTH : natural := 32;  -- AXI itf data width
            ADC_DWIDTH    : natural := 16;  -- ADC data width
            MEM_AWIDTH    : natural := 10;  -- MEM addr width
            MEM_DEPTH     : natural := 1024 --Max 2**16
          );
  port ( 
         start_i           : in std_logic;
         trig_i            : in std_logic;
         send_i            : in std_logic;
         done_o            : out std_logic;

         --start_o           : out std_logic;
         --trig_o            : out std_logic;
         --mode_o            : out std_logic;

         --avg_scope (as) debug signals
         --as_state_mon_o    : out std_logic_vector(4-1 downto 0);
         --as_avg_o          : out std_logic_vector(16-1 downto 0);

         --ntoone (nt) debug signals
         --nt_state_mon_o    : out std_logic_vector(4-1 downto 0);
         --nt_avg_o          : out std_logic_vector(16-1 downto 0);

         --en_o              : out std_logic;
         --nsamples_o        : out std_logic_vector(16-1 downto 0);
         --naverages_o       : out std_logic_vector(16-1 downto 0);
         --tdp_addra_o       : out std_logic_vector(11-1 downto 0);
         --tdp_addrb_o       : out std_logic_vector(11-1 downto 0);
         --bram_en_o         : out std_logic;
         --bram_addr_o       : out std_logic_vector(MEM_AWIDTH-1 downto 0);
         --bram_rddata_o     : out std_logic_vector(M_AXIS_DWIDTH-1 downto 0);
         --bram_en_oo         : out std_logic;
         --bram_addr_oo       : out std_logic_vector(MEM_AWIDTH-1 downto 0);
         --bram_rddata_oo     : out std_logic_vector(M_AXIS_DWIDTH-1 downto 0);

         -- Slave config side
         s_axis_cfg_aclk   : in std_logic;
         s_axis_cfg_aresetn: in std_logic;
         s_axis_cfg_reg_i  : in std_logic_vector(80-1 downto 0);

         -- Slave data interface
         s_axis_aclk       : in std_logic;
         s_axis_aresetn    : in std_logic;
         s_axis_tready     : out std_logic;
         s_axis_tvalid     : in std_logic;
         s_axis_tdata      : in std_logic_vector(S_AXIS_DWIDTH-1 downto 0);

         -- Master data interface
         m_axis_aclk       : in std_logic;
         m_axis_aresetn    : in std_logic;
         m_axis_tready     : in std_logic;
         m_axis_tvalid     : out std_logic;
         m_axis_tlast      : out std_logic;
         m_axis_tkeep      : out std_logic_vector(4-1 downto 0);
         m_axis_tdata      : out std_logic_vector(M_AXIS_DWIDTH-1 downto 0)
       );
end axis_averager;

architecture rtl of axis_averager is

  signal en_as, en_nt          : std_logic;
  signal mode_s, mode_sm       : std_logic;
  signal done_s, as_done, nt_done   : std_logic;
  signal start_sync, trig_sync : std_logic;
  signal start_os, trig_os, send_os : std_logic;
  signal nsamples_s, naverages_s    : std_logic_vector(ADC_DWIDTH-1 downto 0);

  --Register cfg/sts
  signal s_axis_cfg_reg_sync   : std_logic_vector(80-1 downto 0);
  signal m_axis_cfg_reg_sync   : std_logic_vector(80-1 downto 0);
  signal m0_axis_aclk, m1_axis_aclk       : std_logic;
  signal m0_axis_aresetn, m1_axis_aresetn : std_logic;
  signal m0_axis_tdata, m1_axis_tdata     : std_logic_vector(S_AXIS_DWIDTH-1 downto 0);
  signal m0_axis_tvalid, m1_axis_tvalid   : std_logic;
  signal m0_axis_tready, m1_axis_tready   : std_logic;

  signal m00_axis_aclk, m11_axis_aclk       : std_logic;
  signal m00_axis_aresetn, m11_axis_aresetn : std_logic;
  signal m00_axis_tdata, m11_axis_tdata     : std_logic_vector(M_AXIS_DWIDTH-1 downto 0);
  signal m00_axis_tvalid, m11_axis_tvalid   : std_logic;
  signal m00_axis_tready, m11_axis_tready   : std_logic;
  signal m00_axis_tlast, m11_axis_tlast     : std_logic;
  signal m00_axis_tkeep, m11_axis_tkeep     : std_logic_vector(4-1 downto 0);

begin

  --lets synchronize the cfg word
  sync_cfg_s: entity work.n_sync
  generic map(N => 80
             )
  port map(
            aclk     => s_axis_aclk,
            aresetn  => s_axis_aresetn,
            in_async => s_axis_cfg_reg_i,
            out_sync => s_axis_cfg_reg_sync
          );

  --mode_s      <= s_axis_cfg_reg_sync(64-1); 
  --naverages_s <= s_axis_cfg_reg_sync(48-1 downto 32);
  --nsamples_s  <= s_axis_cfg_reg_sync(16-1 downto 0);
  mode_s      <= s_axis_cfg_reg_sync(32); 
  naverages_s <= s_axis_cfg_reg_sync(32-1 downto 16);
  nsamples_s  <= s_axis_cfg_reg_sync(16-1 downto 0);

  --signals for debug
  --mode_o      <= s_axis_cfg_reg_sync(64-1); 
  --naverages_o <= s_axis_cfg_reg_sync(48-1 downto 32);
  --nsamples_o  <= s_axis_cfg_reg_sync(16-1 downto 0);
  en_as       <= not mode_s;
  en_nt       <= mode_s;
  
  --en_o <= en_as;

  os_start: entity work.edge_det
  port map(
            aclk     => s_axis_aclk,
            aresetn  => s_axis_aresetn,
            sig_i    => start_i,
            sig_o    => start_os
          );
  --start_o <= start_os;

  --lets synchronize the send signal
  sync_send_m: entity work.edge_det
  port map(
            aclk     => m_axis_aclk,
            aresetn  => m_axis_aresetn,
            sig_i    => send_i,
            sig_o    => send_os
          );

  os_trig: entity work.edge_det
  port map(
            aclk     => s_axis_aclk,
            aresetn  => s_axis_aresetn,
            sig_i    => trig_i,
            sig_o    => trig_os
          );
  --trig_o <= trig_os;

  --lets synchronize the cfg word
  --sync_cfg_m: entity work.n_sync
  --generic map(N => 80
  --           )
  --port map(
  --          aclk     => m_axis_aclk,
  --          aresetn  => m_axis_aresetn,
  --          in_async => s_axis_cfg_reg_i,
  --          out_sync => m_axis_cfg_reg_sync
  --        );
  ----mode_sm      <= m_axis_cfg_reg_sync(32-1); 
  --mode_sm      <= m_axis_cfg_reg_sync(64-1); 

  --Select the data input
  sig_sel_i: entity work.axis_signal_selector 
  generic map(
               AXIS_DWIDTH => S_AXIS_DWIDTH
             )
  port map(
            sel            => mode_s,
            s_axis_aclk    => s_axis_aclk,
            s_axis_aresetn => s_axis_aresetn,
            s_axis_tdata   => s_axis_tdata,
            s_axis_tvalid  => s_axis_tvalid,
            s_axis_tready  => s_axis_tready,
            
            m0_axis_aclk   => m0_axis_aclk,
            m0_axis_aresetn=> m0_axis_aresetn,
            m0_axis_tdata  => m0_axis_tdata,
            m0_axis_tvalid => m0_axis_tvalid,
            m0_axis_tready => m0_axis_tready,

            m1_axis_aclk   => m1_axis_aclk,
            m1_axis_aresetn=> m1_axis_aresetn,
            m1_axis_tdata  => m1_axis_tdata,
            m1_axis_tvalid => m1_axis_tvalid,
            m1_axis_tready => m1_axis_tready
);

  --Averager scope
  avg_scope_i: entity work.avg_scope 
  generic map(
               I_DWIDTH   => S_AXIS_DWIDTH,
               O_DWIDTH   => M_AXIS_DWIDTH,
               ADC_DWIDTH => ADC_DWIDTH,
               MEM_AWIDTH => MEM_AWIDTH,
               MEM_DEPTH  => MEM_DEPTH
             )
  port map(
            start_i        => start_os,
            send_i         => send_os,
            trig_i         => trig_os,
            done_o         => as_done,
            --state_mon      => as_state_mon_o,
            en_i           => en_as,
            naverages_i    => naverages_s,
            nsamples_i     => nsamples_s,
            --bram_en_o      => bram_en_o,
            --bram_addr_o    => bram_addr_o,
            --bram_rddata_o  => bram_rddata_o,
            --bram_en_oo      => bram_en_oo,
            --bram_addr_oo    => bram_addr_oo,
            --bram_rddata_oo  => bram_rddata_oo,

            --avg_o          => as_avg_o,

            --tdp_addra_o    => tdp_addra_o,
            --tdp_addrb_o    => tdp_addrb_o,

            s_axis_cfg_aclk=> s_axis_cfg_aclk,
            s_axis_cfg_aresetn => s_axis_cfg_aresetn,

            s_axis_aclk    => m0_axis_aclk,
            s_axis_aresetn => m0_axis_aresetn,
            s_axis_tready  => m0_axis_tready,
            s_axis_tvalid  => m0_axis_tvalid,
            s_axis_tdata   => m0_axis_tdata,

            m_axis_aclk    => m_axis_aclk,
            m_axis_aresetn => m_axis_aresetn,
            m_axis_tready  => m00_axis_tready,
            m_axis_tdata   => m00_axis_tdata,
            m_axis_tvalid  => m00_axis_tvalid,
            m_axis_tlast   => m00_axis_tlast,
            m_axis_tkeep   => m00_axis_tkeep
          );

  --Averager N to One
  avg_ntoone_i: entity work.avg_ntoone 
  generic map(
               I_DWIDTH   => S_AXIS_DWIDTH,
               O_DWIDTH   => M_AXIS_DWIDTH,
               ADC_DWIDTH => ADC_DWIDTH,
               MEM_AWIDTH => MEM_AWIDTH,
               MEM_DEPTH  => MEM_DEPTH
             )
  port map(
            start_i        => start_os,
            send_i         => send_os,
            trig_i         => trig_os,
            done_o         => nt_done,
            --state_mon      => nt_state_mon_o,
            en_i           => en_nt,
            naverages_i    => naverages_s,
            nsamples_i     => nsamples_s,
            --avg_o          => nt_avg_o,

            s_axis_cfg_aclk=> s_axis_cfg_aclk,
            s_axis_cfg_aresetn => s_axis_cfg_aresetn,

            s_axis_aclk    => m1_axis_aclk,
            s_axis_aresetn => m1_axis_aresetn,
            s_axis_tready  => m1_axis_tready,
            s_axis_tvalid  => m1_axis_tvalid,
            s_axis_tdata   => m1_axis_tdata,

            m_axis_aclk    => m_axis_aclk,
            m_axis_aresetn => m_axis_aresetn,
            m_axis_tready  => m11_axis_tready,
            m_axis_tdata   => m11_axis_tdata,
            m_axis_tvalid  => m11_axis_tvalid,
            m_axis_tlast   => m11_axis_tlast,
            m_axis_tkeep   => m11_axis_tkeep
          );

  done_s <= nt_done when (mode_s = '1') else as_done;
  --lets synchronize the done signal
  sync_done: entity work.sync
  port map(
            aclk     => s_axis_cfg_aclk,
            aresetn  => s_axis_cfg_aresetn,
            in_async => done_s,
            out_sync => done_o
          );

  --Mux the output data
  sig_mux_i: entity work.axis_signal_mux 
  generic map(
               AXIS_DWIDTH => M_AXIS_DWIDTH
             )
  port map(
            sel            => mode_s, --m,

            s0_axis_tdata   => m00_axis_tdata,
            s0_axis_tvalid  => m00_axis_tvalid,
            s0_axis_tready  => m00_axis_tready,
            s0_axis_tlast   => m00_axis_tlast,
            s0_axis_tkeep   => m00_axis_tkeep,

            s1_axis_tdata   => m11_axis_tdata,
            s1_axis_tvalid  => m11_axis_tvalid,
            s1_axis_tready  => m11_axis_tready,
            s1_axis_tlast   => m11_axis_tlast,
            s1_axis_tkeep   => m11_axis_tkeep,

            m_axis_tdata   => m_axis_tdata,
            m_axis_tvalid  => m_axis_tvalid,
            m_axis_tready  => m_axis_tready,
            m_axis_tlast   => m_axis_tlast,
            m_axis_tkeep   => m_axis_tkeep

);

end rtl;
