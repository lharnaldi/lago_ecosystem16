library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_averager is
  generic (
            S_AXIS_DWIDTH : natural := 128; -- AXIS itf data width
            M_AXIS_DWIDTH : natural := 16;  -- AXI itf data width
            ADC_DWIDTH    : natural := 16;  -- ADC data width
            MEM_AWIDTH    : natural := 10;  -- MEM addr width
            MEM_DEPTH     : natural := 1024 --Max 2**16
          );
  port ( 
         start_i           : in std_logic;
         trig_i            : in std_logic;
         send_i            : in std_logic;
         done_o            : out std_logic;

         --avg_scope (as) debug signals
         as_state_mon_o    : out std_logic_vector(4-1 downto 0);
         as_avg_o          : out std_logic_vector(16-1 downto 0);

         --ntoone (nt) debug signals
         nt_state_mon_o    : out std_logic_vector(4-1 downto 0);
         nt_avg_o          : out std_logic_vector(16-1 downto 0);

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

  signal mode_s, mode_sm       : std_logic;
  signal as_done, nt_done      : std_logic;

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

  mode_s      <= s_axis_cfg_reg_sync(32-1); 

  --lets synchronize the cfg word
  sync_cfg_m: entity work.n_sync
  generic map(N => 80
             )
  port map(
            aclk     => m_axis_aclk,
            aresetn  => m_axis_aresetn,
            in_async => s_axis_cfg_reg_i,
            out_sync => m_axis_cfg_reg_sync
          );

  mode_sm      <= m_axis_cfg_reg_sync(32-1); 

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
            start_i        => start_i,
            send_i         => send_i,
            trig_i         => trig_i,
            done_o         => as_done,
            state_mon      => as_state_mon_o,
            cfg_data_i     => s_axis_cfg_reg_sync,
            avg_o          => as_avg_o,

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
            start_i        => start_i,
            send_i         => send_i,
            trig_i         => trig_i,
            done_o         => nt_done,
            state_mon      => nt_state_mon_o,
            cfg_data_i     => s_axis_cfg_reg_sync,
            avg_o          => nt_avg_o,

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

  done_o <= as_done when (mode_s = '0') else nt_done;

  --Mux the output data
  sig_mux_i: entity work.axis_signal_mux 
  generic map(
               AXIS_DWIDTH => M_AXIS_DWIDTH
             )
  port map(
            sel            => mode_sm,

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
