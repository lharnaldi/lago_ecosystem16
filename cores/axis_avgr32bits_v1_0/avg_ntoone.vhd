library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity avg_ntoone is
  generic (
            I_DWIDTH   : natural := 128; -- ADC data width x8
            O_DWIDTH   : natural := 32;  -- AXI data width
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
         --state_mon      : out std_logic_vector(3 downto 0);
         --nsamples Must be power of 2. Minimum is 8 and maximum is 2^AW
         en_i           : in std_logic;
         naverages_i    : in std_logic_vector(ADC_DWIDTH-1 downto 0);
         nsamples_i     : in std_logic_vector(ADC_DWIDTH-1 downto 0);

         --avg_o          : out std_logic_vector(O_DWIDTH-1 downto 0);

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
signal tdp_dia     : std_logic_vector(O_DWIDTH-1 downto 0);
signal tdp_doa     : std_logic_vector(O_DWIDTH-1 downto 0);
signal data_reg, data_next       : std_logic_vector(2*I_DWIDTH-1 downto 0);
signal samples_reg, samples_next : unsigned(ADC_DWIDTH-1 downto 0);

signal done_s, tready_s : std_logic;
signal avg_reg, avg_next       : unsigned(ADC_DWIDTH-1 downto 0);
signal restart_s, restart_os   : std_logic;

signal bram_clk  : std_logic;
signal bram_rst  : std_logic;
signal bram_en   : std_logic;
signal bram_addr : std_logic_vector(MEM_AWIDTH-1 downto 0);
signal bram_rddata : std_logic_vector(O_DWIDTH-1 downto 0);
signal naverages_b : std_logic_vector(O_DWIDTH-1 downto 0);

begin

  s_axis_tready <= tready_s;
  --avg_o         <= std_logic_vector(avg_reg);
  done_o        <= done_s;

  -- TDP RAM
  tdp_ram_i : entity work.tdp_ram_pip
  generic map(
               AWIDTH       => MEM_AWIDTH,
               DWIDTH       => O_DWIDTH
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
  process(state_reg, en_i, start_i, trig_i, nsamples_i,
    naverages_i, tdp_addra_reg, tdp_dia, data_reg, samples_reg,
    s_axis_tvalid, s_axis_tdata, avg_reg, m_axis_tready, restart_os)
    variable dinbv : std_logic_vector(O_DWIDTH-1 downto 0);
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
        --state_mon      <= "0000"; --state mon
        samples_next   <= (others => '0');
        tdp_addra_next <= (others => '0');
        avg_next       <= (others => '0');
        data_next      <= (others => '0');
        if en_i = '1' and start_i = '1' then
          state_next  <= ST_WAIT_TRIG;
        else
          state_next  <= ST_IDLE;
        end if;

      when ST_WAIT_TRIG => -- Wait for trigger
        --state_mon <= "0001"; --state mon
        if(trig_i = '1') then
          state_next    <= ST_AVG_N1;
        else
          state_next <= ST_WAIT_TRIG;
        end if;

      when ST_AVG_N1 => 
        --state_mon <= "0010"; 
        if (s_axis_tvalid = '1') then
        tready_s <= '1';
        samples_next <= samples_reg + 1;
        ASSIGN_N: for I in 0 to RATIO-1 loop
          data_next(2*I_DWIDTH-1-I*O_DWIDTH downto 2*I_DWIDTH-(I+1)*O_DWIDTH) <=
          std_logic_vector(signed(data_reg(2*I_DWIDTH-1-I*O_DWIDTH downto 2*I_DWIDTH-(I+1)*O_DWIDTH)) +
          resize(signed(s_axis_tdata(I_DWIDTH-1-I*ADC_DWIDTH downto I_DWIDTH-((I+1)*ADC_DWIDTH))),O_DWIDTH));
        end loop;
        if(samples_reg = (unsigned(nsamples_i)/RATIO)-1) then
          samples_next <= (others => '0');
          state_next  <= ST_WRITE_AVG;
        end if;
      end if;

      when ST_WRITE_AVG => 
        --state_mon <= "0011"; 
        dinbv := (others => '0');
        ASSIGN_AVG1: for K in 0 to RATIO-1 loop
          dinbv := std_logic_vector(signed(dinbv) + signed(data_reg(2*I_DWIDTH-1-K*O_DWIDTH downto 2*I_DWIDTH-(K+1)*O_DWIDTH)));
        end loop;
        tdp_dia <= dinbv;
        tdp_wea <= '1';
        data_next <= (others => '0');
        tdp_addra_next <= tdp_addra_reg + 1;
        avg_next <= avg_reg + 1;
        if (avg_reg = unsigned(naverages_i)-1) then
          state_next <= ST_FINISH;
        else
          state_next <= ST_WAIT_TRIG;
        end if;

      when ST_FINISH => 
        --state_mon <= "0100"; 
        done_s    <= '1';
        if restart_os = '1' then
          state_next <= ST_IDLE;
        end if;

    end case;
  end process;

  --lets synchronize the restart signal
  os_restart_nt: entity work.edge_det
  port map(
            aclk     => s_axis_aclk,
            aresetn  => s_axis_aresetn,
            sig_i    => restart_s,
            sig_o    => restart_os
          );

  naverages_b <= (31 downto 16 => '0') & naverages_i;
  reader_i: entity work.bram_reader_nt 
  generic map(
               MEM_DEPTH   => MEM_DEPTH,
               MEM_AWIDTH  => MEM_AWIDTH,
               AXIS_DWIDTH => O_DWIDTH
             )
  port map(

            cfg_data_i     => naverages_s,
            --sts_data_o     => open,
            done_i         => done_s,
            send_i         => send_i,
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
