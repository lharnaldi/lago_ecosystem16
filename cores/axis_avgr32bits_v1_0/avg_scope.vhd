library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity avg_scope is
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
         --avg_o          : out std_logic_vector(16-1 downto 0);

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
end avg_scope;

architecture rtl of avg_scope is

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
  ST_EN_TDPB,
  ST_AVG_SCOPE,
  ST_FINISH,
  ST_WR_ZEROS
);
signal state_reg, state_next      : state_t;

signal rstb_s   : std_logic;
signal tdp_wea  : std_logic;
signal tdp_addra_reg, tdp_addra_next : unsigned(MEM_AWIDTH-1 downto 0);
signal tdp_enb  : std_logic;
signal tdp_addrb_reg, tdp_addrb_next : unsigned(MEM_AWIDTH-1 downto 0);
signal addrb_s                       : std_logic_vector(MEM_AWIDTH-1 downto 0);


signal done_s, tready_s : std_logic;
signal avg_reg, avg_next       : unsigned(ADC_DWIDTH-1 downto 0);
signal en_s, restart_s         : std_logic;
signal start_sync, trig_sync, send_sync, restart_sync  : std_logic;

signal bram_clk  : std_logic;
signal bram_rst  : std_logic;
signal bram_en   : std_logic;
signal bram_addr : std_logic_vector(MEM_AWIDTH-1 downto 0);
signal bram_rddata : std_logic_vector(2*I_DWIDTH-1 downto 0);

type vect_t is array (0 to RATIO-1) of std_logic_vector(O_DWIDTH-1 downto 0);
signal in_reg, in_next : vect_t;
signal tdp_dia, tdp_doa, tdp_dob, bram_rddata_s : vect_t;
signal tvalid_reg, tvalid_next : std_logic;
signal reader_cfg              : std_logic_vector(16-1 downto 0);

begin

  --en_s <= not cfg_data_i(32); --mode=0 enables this block
  --naverages_s <= cfg_data_i(32-1 downto 16);
  --nsamples_s <= cfg_data_i(16-1 downto 0);

  s_axis_tready <= tready_s;
  --avg_o         <= std_logic_vector(avg_reg);
  done_o <= done_s;

  -- TDP RAM
  -- input assignment 
  process(s_axis_tvalid, s_axis_tdata)
  begin
    if (s_axis_tvalid = '1') then
      for k in 0 to RATIO-1  loop
        in_next(k) <= std_logic_vector(resize(signed(s_axis_tdata(I_DWIDTH-1-k*ADC_DWIDTH downto I_DWIDTH-(k+1)*ADC_DWIDTH)),O_DWIDTH));
      end loop;
    else
      for k in 0 to RATIO-1 loop
        in_next(k) <= in_reg(k);
      end loop;
    end if;
  end process;

  BRAM_CALC_inst: for j in 0 to RATIO-1 generate
  tdp_ram_i : entity work.tdp_ram_pip
  generic map(
               AWIDTH       => MEM_AWIDTH, 
               DWIDTH       => O_DWIDTH
             )
  port map(
            clka  => s_axis_aclk,
            --rsta  => rsta_s,
            wea   => tdp_wea,
            addra => std_logic_vector(tdp_addra_reg),
            dia   => tdp_dia(j),

            clkb  => s_axis_aclk,
            rstb  => rstb_s,
            enb   => tdp_enb, --'1',
            addrb => std_logic_vector(tdp_addrb_reg),
            dob   => tdp_dob(j)
          );
end generate;

  BRAM_OUT_inst: for j in 0 to RATIO-1 generate
  tdp_ram_i : entity work.tdp_ram_pip
  generic map(
               AWIDTH       => MEM_AWIDTH, 
               DWIDTH       => O_DWIDTH
             )
  port map(
            clka  => s_axis_aclk,
            wea   => tdp_wea,
            addra => std_logic_vector(tdp_addra_reg),
            dia   => tdp_dia(j),

            clkb  => bram_clk,   
            rstb  => bram_rst,  
            enb   => bram_en,  
            addrb => bram_addr, 
            dob   => bram_rddata_s(j)
          );
end generate;

process(bram_rddata_s)
begin
  for k in 0 to RATIO-1 loop
    bram_rddata(2*I_DWIDTH-1-k*O_DWIDTH downto 2*I_DWIDTH-(k+1)*O_DWIDTH) <= bram_rddata_s(RATIO-1-k);
  end loop;
end process;

  process(s_axis_aclk)
  begin
    if rising_edge(s_axis_aclk) then
      if (s_axis_aresetn = '0') then
        state_reg     <= ST_IDLE;
        in_reg        <= (others => (others => '0'));
        tvalid_reg    <= '0';
        tdp_addra_reg <= (others => '0');
        tdp_addrb_reg <= (others => '0');
        avg_reg       <= (others => '0');
      else
        state_reg     <= state_next;
        in_reg        <= in_next;
        tvalid_reg    <= tvalid_next;
        tdp_addra_reg <= tdp_addra_next;
        tdp_addrb_reg <= tdp_addrb_next;
        avg_reg       <= avg_next;
      end if;
    end if;
  end process;

  tvalid_next <= s_axis_tvalid; -- one clk delay

  --Next state logic
  process(state_reg, en_i, start_i, trig_i, nsamples_i, naverages_i, 
    tdp_addra_reg, tdp_addrb_reg, tdp_dia, tvalid_reg, 
    avg_reg, m_axis_tready, restart_os)
  begin
    state_next    <= state_reg;
    rstb_s        <= '0';
    tdp_wea       <= '0';
    tdp_addra_next<= tdp_addra_reg;
    tdp_dia       <= (others => (others => '0')); 
    tdp_enb       <= '0';
    tdp_addrb_next<= tdp_addrb_reg;
    tready_s      <= '0';
    avg_next      <= avg_reg;
    done_s        <= '0';

    case state_reg is
      when ST_IDLE => -- Start
        rstb_s         <= '1';
        tdp_addra_next <= (others => '0');
        tdp_addrb_next <= (others => '0');
        avg_next       <= (others => '0');
        if en_i = '1' and start_i = '1' then
          state_next  <= ST_WAIT_TRIG;
        else
          state_next  <= ST_IDLE;
        end if;

      when ST_WAIT_TRIG => -- Wait for trigger
        if(trig_i = '1') then
          state_next  <= ST_EN_TDPB;
        else
          state_next <= ST_WAIT_TRIG;
        end if;

      when ST_EN_TDPB =>
        if (tvalid_reg = '1') then
          tdp_enb        <= '1';
          tdp_addrb_next <= tdp_addrb_reg + 1;
          state_next     <= ST_AVG_SCOPE;
        end if;

      when ST_AVG_SCOPE => -- Measure
        if (tvalid_reg = '1') then
          tready_s <= '1';
          tdp_enb  <= '1';
          tdp_wea  <= '1';
          tdp_addra_next <= tdp_addra_reg + 1;
          tdp_addrb_next <= tdp_addrb_reg + 1;
          ASSIGN_G1: for I in 0 to RATIO-1 loop
            tdp_dia(I) <= std_logic_vector(signed(tdp_dob(I)) + signed(in_reg(I)));
          end loop;
          if(tdp_addra_reg = (unsigned(nsamples_i)/RATIO)-1) then
            tdp_addra_next <= (others => '0');
            tdp_addrb_next <= (others => '0');
            avg_next <= avg_reg + 1;
            if (avg_reg = unsigned(naverages_i)-1) then
              state_next  <= ST_FINISH;
            else
              state_next  <= ST_WAIT_TRIG;
            end if;
          end if;
        else 
          state_next <= ST_AVG_SCOPE;
        end if;

      when ST_FINISH => 
        done_s    <= '1';
        if restart_os = '1' then
          state_next <= ST_WR_ZEROS;
        end if;

      when ST_WR_ZEROS => 
        state_mon <= "0101";
        tdp_wea   <= '1';
        tdp_addra_next <= tdp_addra_reg + 1; 
        if (tdp_addra_reg = (unsigned(nsamples_i)/RATIO)-1) then
          state_next <= ST_IDLE;
        end if;

    end case;
  end process;

  --lets synchronize the restart signal
  os_restart_as: entity work.edge_det
  port map(
            aclk     => s_axis_aclk,
            aresetn  => s_axis_aresetn,
            sig_i    => restart_s,
            sig_o    => restart_os
          );

  reader_cfg <= std_logic_vector(unsigned(nsamples_i)/RATIO);
  reader_i: entity work.bram_reader 
  generic map(
            MEM_DEPTH   => MEM_DEPTH,
            MEM_AWIDTH  => MEM_AWIDTH,
            DRATIO      => RATIO,
            AXIS_DWIDTH => O_DWIDTH
          )
  port map(

         cfg_data_i     => reader_cfg, --nsamples_s,
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
