library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity avg_ntoone is
  generic (
            I_DWIDTH   : natural := 128; -- ADC data width x8
            O_DWIDTH   : natural := 16;  -- AXI data width
            ADC_DWIDTH : natural := 16;  -- ADC data width
            MEM_AWIDTH : natural := 10;  --
            MEM_DEPTH  : natural := 1024 -- Max 2**16
          );
  port (
         -- Averager specific ports
         start_i        : in std_logic;
         send_i         : in std_logic;
         trig_i         : in std_logic;
         done_o         : out std_logic;
         state_mon      : out std_logic_vector(3 downto 0);
         --nsamples Must be power of 2. Minimum is 8 and maximum is 2^AW
         cfg_data_i     : in std_logic_vector(80-1 downto 0);
         avg_o          : out std_logic_vector(16-1 downto 0);

         s_axis_cfg_aclk    : in std_logic;
         s_axis_cfg_aresetn : in std_logic;

         -- Slave side
         s_axis_aclk    : in std_logic;
         s_axis_aresetn : in std_logic;
         s_axis_tready  : out std_logic;
         s_axis_tvalid  : in std_logic;
         s_axis_tdata   : in std_logic_vector(I_DWIDTH-1 downto 0);

         -- Master side
         m_axis_aclk    : in std_logic;
         m_axis_aresetn : in std_logic;
         m_axis_tready  : in std_logic;
         m_axis_tdata   : out std_logic_vector(O_DWIDTH-1 downto 0);
         m_axis_tvalid  : out std_logic;
         m_axis_tlast   : out std_logic;
         m_axis_tkeep   : out std_logic_vector(4-1 downto 0)
       );
end avg_ntoone;

architecture rtl of avg_ntoone is

  function log2c(n: integer) return integer is
    variable m, p: integer;
  begin
    m := 0;
    p := 1;
    while p < n loop
      m := m + 1;
      p := p * 2;
    end loop;
    return m;
  end log2c;

  constant RATIO : natural := I_DWIDTH/ADC_DWIDTH;

  type state_t is (
  ST_IDLE,
  ST_WAIT_TRIG,
  ST_AVG_N1,
  ST_WRITE_AVG,
  ST_FINISH
);
signal state_reg, state_next      : state_t;

signal tdp_wea     : std_logic;
signal tdp_addra_reg, tdp_addra_next : unsigned(MEM_AWIDTH-1 downto 0);
signal tdp_dia     : std_logic_vector(ADC_DWIDTH-1 downto 0);
signal tdp_doa     : std_logic_vector(ADC_DWIDTH-1 downto 0);
signal data_reg, data_next       : std_logic_vector(I_DWIDTH-1 downto 0);
signal samples_reg, samples_next : unsigned(ADC_DWIDTH-1 downto 0);

signal done_s, tready_s : std_logic;
signal avg_reg, avg_next       : unsigned(ADC_DWIDTH-1 downto 0);
signal nsamples_s, naverages_s : std_logic_vector(16-1 downto 0);
signal en_s, restart_s         : std_logic;
signal start_sync, trig_sync, send_sync, restart_sync  : std_logic;

signal bram_clk  : std_logic;
signal bram_rst  : std_logic;
signal bram_en   : std_logic;
signal bram_addr : std_logic_vector(MEM_AWIDTH-1 downto 0);
signal bram_rddata : std_logic_vector(O_DWIDTH-1 downto 0);

begin

  en_s <= cfg_data_i(32-1); --mode=1 enables this block
  naverages_s <= '0' & cfg_data_i(32-2 downto 16);
  nsamples_s <= cfg_data_i(16-1 downto 0);

  s_axis_tready <= tready_s;
  avg_o         <= std_logic_vector(avg_reg);

  --lets synchronize the start signal
  sync_start: entity work.sync
  port map(
            aclk     => s_axis_aclk,
            aresetn  => s_axis_aresetn,
            in_async => start_i,
            out_sync => start_sync
          );

  --lets synchronize the trigger signal
  sync_trig: entity work.sync
  port map(
            aclk     => s_axis_aclk,
            aresetn  => s_axis_aresetn,
            in_async => trig_i,
            out_sync => trig_sync
          );

  --lets synchronize the done signal
  sync_done: entity work.sync
  port map(
            aclk     => s_axis_cfg_aclk,
            aresetn  => s_axis_cfg_aresetn,
            in_async => done_s,
            out_sync => done_o
          );

  -- TDP RAM
  tdp_ram_i : entity work.tdp_ram_pip
  generic map(
               AWIDTH       => MEM_AWIDTH,
               DWIDTH       => ADC_DWIDTH
             )
  port map(
            clka  => s_axis_aclk,
            wea   => tdp_wea,
            addra => std_logic_vector(tdp_addra_reg),
            dia   => tdp_dia,

            clkb  => bram_clk,
            rstb  => bram_rst,
            enb   => bram_en,
            addrb => bram_addr,
            dob   => bram_rddata
          );

  process(s_axis_aclk)
  begin
    if rising_edge(s_axis_aclk) then
      if (s_axis_aresetn = '0') then
        state_reg     <= ST_IDLE;
        tdp_addra_reg <= (others => '0');
        data_reg      <= (others => '0');
        samples_reg   <= (others => '0');
        avg_reg       <= (others => '0');
      else
        state_reg     <= state_next;
        tdp_addra_reg <= tdp_addra_next;
        data_reg      <= data_next;
        samples_reg   <= samples_next;
        avg_reg       <= avg_next;
      end if;
    end if;
  end process;

  --Next state logic
  process(state_reg, en_s, start_sync, trig_sync, nsamples_s,
    naverages_s, tdp_addra_reg, tdp_dia, data_reg, samples_reg,
    s_axis_tvalid, avg_reg, m_axis_tready,restart_sync)
    variable dinbv : std_logic_vector(ADC_DWIDTH-1 downto 0);
  begin
    state_next    <= state_reg;
    tdp_wea       <= '0';
    tdp_addra_next<= tdp_addra_reg;
    data_next     <= data_reg;
    samples_next  <= samples_reg;
    tdp_dia       <= (others => '0'); 
    tready_s      <= '0';
    avg_next      <= avg_reg;
    done_s        <= '0';

    case state_reg is
      when ST_IDLE => -- Start
        state_mon      <= "0000"; --state mon
        tdp_addra_next <= (others => '0');
        avg_next       <= (others => '0');
        if en_s = '1' and start_sync = '1' then
          state_next  <= ST_WAIT_TRIG;
        else
          state_next  <= ST_IDLE;
        end if;

      when ST_WAIT_TRIG => -- Wait for trigger
        state_mon <= "0001"; --state mon
        if(trig_i = '1') then
          state_next    <= ST_AVG_N1;
        else
          state_next <= ST_WAIT_TRIG;
        end if;

      when ST_AVG_N1 => 
        state_mon <= "0010"; 
        tready_s <= '1';
        if (s_axis_tvalid = '1') then
        samples_next <= samples_reg + 1;
        ASSIGN_N: for I in 0 to RATIO-1 loop
          data_next(I_DWIDTH-1-I*ADC_DWIDTH downto I_DWIDTH-(I+1)*ADC_DWIDTH) <=
          std_logic_vector(signed(data_reg(I_DWIDTH-1-I*ADC_DWIDTH downto I_DWIDTH-(I+1)*ADC_DWIDTH)) +
          resize(signed(s_axis_tdata(I_DWIDTH-1-I*ADC_DWIDTH downto I_DWIDTH-((I+1)*ADC_DWIDTH)+4)),ADC_DWIDTH));
        end loop;
        if(samples_reg = (unsigned(nsamples_s)/RATIO)-1) then
          samples_next <= (others => '0');
          state_next  <= ST_WRITE_AVG;
        end if;
      end if;

      when ST_WRITE_AVG => 
        state_mon <= "0011"; 
        avg_next <= avg_reg + 1;
        dinbv := (others => '0');
        ASSIGN_AVG1: for K in 0 to RATIO-1 loop
          dinbv := std_logic_vector(signed(dinbv) + signed(data_reg(I_DWIDTH-1-K*ADC_DWIDTH downto I_DWIDTH-(K+1)*ADC_DWIDTH)));
        end loop;
        tdp_dia <= dinbv;
        tdp_wea <= '1';
        data_next <= (others => '0');
        tdp_addra_next <= tdp_addra_reg + 1;
        if (avg_reg = unsigned(naverages_s)-1) then
          state_next <= ST_FINISH;
        else
          state_next <= ST_WAIT_TRIG;
        end if;

      when ST_FINISH => 
        state_mon <= "0100"; 
        done_s    <= '1';
        if restart_sync = '1' then
          state_next <= ST_IDLE;
        end if;

    end case;
  end process;

  --lets synchronize the send signal
  sync_send_m: entity work.sync
  port map(
            aclk     => m_axis_aclk,
            aresetn  => m_axis_aresetn,
            in_async => send_i,
            out_sync => send_sync
          );

  --lets synchronize the restart signal
  sync_restart: entity work.sync
  port map(
            aclk     => s_axis_aclk,
            aresetn  => s_axis_aresetn,
            in_async => restart_s,
            out_sync => restart_sync
          );

  reader_i: entity work.bram_reader 
  generic map(
               MEM_DEPTH   => MEM_DEPTH,
               MEM_AWIDTH  => MEM_AWIDTH,
               AXIS_DWIDTH => O_DWIDTH
             )
  port map(

            cfg_data_i     => naverages_s,
            sts_data_o     => open,
            done_i         => done_s,
            send_i         => send_sync,
            restart_o      => restart_s,

         -- Master side
            aclk           => m_axis_aclk,
            aresetn        => m_axis_aresetn,
            m_axis_tready  => m_axis_tready,
            m_axis_tdata   => m_axis_tdata,
            m_axis_tvalid  => m_axis_tvalid,
            m_axis_tlast   => m_axis_tlast, 
            m_axis_tkeep   => m_axis_tkeep, 
         -- BRAM port
            bram_clk       => bram_clk,   
            bram_rst       => bram_rst,
            bram_en        => bram_en,
            bram_addr      => bram_addr,
            bram_rddata    => bram_rddata
          );

end rtl;
