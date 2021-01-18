library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity averager is
  generic (
            IN_DATA_WIDTH  : natural := 128; -- ADC data width x8
            OUT_DATA_WIDTH : natural := 32;  -- AXI data width
            ADC_DATA_WIDTH : natural := 16;  -- ADC data width
            MEM_AWIDTH     : natural := 10;  -- 
            MEM_DEPTH      : natural := 1024 -- Max 2**16
          );
  port ( 
         -- System signals
         aclk              : in std_logic;
         aresetn           : in std_logic;

         -- Averager specific ports
         start             : in std_logic;
         restart           : in std_logic;
         mode              : in std_logic; --0- (default) avg scope, 1-avg nsamples to one value
         trig_i            : in std_logic;
         READOUT_State_Mon : out std_logic_vector(2 downto 0);
         --nsamples Must be power of 2. Minimum is 8 and maximum is 2^AW
         nsamples          : in std_logic_vector(32-1 downto 0); 
         naverages         : in std_logic_vector(32-1 downto 0);
         done              : out std_logic;
         averages_out      : out std_logic_vector(32-1 downto 0);
         tdp_ena_o         : out std_logic;            
         op_we_o           : out std_logic;            
         op_addr_o         : out std_logic_vector(MEM_AWIDTH-1 downto 0);
         op_din_o          : out std_logic_vector(2*ADC_DATA_WIDTH-1 downto 0);

         -- BRAM PORTA. Reading port
         bram_porta_clk    : in std_logic;
         bram_porta_addr   : in std_logic_vector(MEM_AWIDTH-1 downto 0);
         bram_porta_rddata : out std_logic_vector(OUT_DATA_WIDTH-1 downto 0);

         -- Slave side     
         s_axis_tready     : out std_logic;
         s_axis_tvalid     : in std_logic;
         s_axis_tdata      : in std_logic_vector(IN_DATA_WIDTH-1 downto 0)
       );
end averager;

architecture rtl of averager is

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

  constant RATIO          : natural := IN_DATA_WIDTH/ADC_DATA_WIDTH;

  type state_t is (
  ST_IDLE, 
  ST_WAIT_TRIG, 
  ST_AVG_SCOPE,
  ST_AVG_N1,
  ST_WRITE_AVG,
  ST_FINISH 
);
signal state_reg, state_next      : state_t;

signal sdp_we_reg, sdp_we_next       : std_logic;
signal sdp_addra_reg, sdp_addra_next : unsigned(log2c(MEM_DEPTH/RATIO)-1 downto 0);
signal sdp_addrb_reg, sdp_addrb_next : unsigned(log2c(MEM_DEPTH/RATIO)-1 downto 0);
signal sdp_di_reg, sdp_di_next       : std_logic_vector(2*IN_DATA_WIDTH-1 downto 0);
signal sdp_doa, sdp_dob              : std_logic_vector(2*IN_DATA_WIDTH-1 downto 0);

signal op_addr_reg, op_addr_next     : unsigned(MEM_AWIDTH-1 downto 0);
signal op_din_reg, op_din_next       : std_logic_vector(2*ADC_DATA_WIDTH-1 downto 0);
signal op_we_reg, op_we_next         : std_logic := '0';
signal op_do     : std_logic_vector(2*ADC_DATA_WIDTH-1 downto 0);
signal tdp_ena   : std_logic := '0';
signal tdp_enb   : std_logic := '0';

signal asy_enb   : std_logic := '0';
signal asy_ena   : std_logic := '0';
signal asy_web   : std_logic := '0';
signal asy_doa   : std_logic_vector(2*ADC_DATA_WIDTH-1 downto 0);
signal asy_dib   : std_logic_vector(2*IN_DATA_WIDTH-1 downto 0);

signal asy_pa_addr_reg, asy_pa_addr_next : unsigned(log2c(MEM_DEPTH/RATIO)-1 downto 0);
signal asy_pa_di_reg, asy_pa_di_next     : std_logic_vector(2*IN_DATA_WIDTH-1 downto 0);

signal tready_reg, tready_next    : std_logic;

signal averages_reg, averages_next: unsigned(2*ADC_DATA_WIDTH-1 downto 0);
signal done_reg, done_next        : std_logic;

begin

  --debug output
  tdp_ena_o         <= tdp_ena;            
  op_we_o           <= op_we_reg;
  op_addr_o         <= std_logic_vector(op_addr_reg);
  op_din_o          <= op_din_reg;

  s_axis_tready     <= tready_reg;
  done              <= done_reg;
  averages_out      <= std_logic_vector(averages_reg);

  bram_porta_rddata <= asy_doa when (mode = '0') else op_do;

  -- TDP RAM
  tdp_ram_i : entity work.tdp_bram
  generic map(
               AWIDTH       => MEM_AWIDTH,
               DWIDTH       => 2*ADC_DATA_WIDTH 
             )
  port map(
            clka  => aclk,
            clkb  => bram_porta_clk,
            ena   => tdp_ena,
            enb   => tdp_enb,
            wea   => op_we_reg,
            addra => std_logic_vector(op_addr_reg),
            addrb => bram_porta_addr,
            dia   => op_din_reg,
            doa   => open,
            dob   => op_do
          );
  tdp_ena <= '1' when mode = '1' and done_reg = '0' else '0';
  tdp_enb <= '1' when mode = '1' and done_reg = '1' else '0';

  -- DP RAM
  sdp_ram_i : entity work.sdp_ram_oc
  generic map(
               AWIDTH       => log2c(MEM_DEPTH/RATIO),
               DWIDTH       => 2*IN_DATA_WIDTH
             )
  port map(
            clk   => aclk,
            ena   => '1',
            enb   => '1',
            wea   => sdp_we_reg,
            addra => std_logic_vector(sdp_addra_reg),
            addrb => std_logic_vector(sdp_addrb_reg),
            dia   => sdp_di_reg,
            dob   => sdp_dob
          );

  -- ASYMMETRIC RAM
  -- Port A -> AXI IF
  -- Port B -> same as WIDER BRAM
  ram_asy : entity work.asym_ram_tdp_write_first
  generic map
  (
    WIDTHA      => 2*ADC_DATA_WIDTH, 
    SIZEA       => MEM_DEPTH,
    ADDRWIDTHA  => MEM_AWIDTH,
    WIDTHB      => 2*IN_DATA_WIDTH,
    SIZEB       => (MEM_DEPTH/RATIO),
    ADDRWIDTHB  => log2c(MEM_DEPTH/RATIO)
  )
  port map
  (
    --portA same as op_ram
    clkA        => bram_porta_clk,
    enA         => asy_ena,
    weA         => '0', 
    addrA       => bram_porta_addr,
    diA         => (others => '0'), 
    doA         => asy_doa, 

    --portB same as portA in dp_ram
    clkB        => aclk, 
    enB         => asy_enb,
    weB         => sdp_we_reg,
    addrB       => std_logic_vector(sdp_addra_reg),
    diB         => sdp_di_reg,
    doB         => open 
  );
  asy_ena <= '1' when mode = '0' and done_reg = '1' else '0';
  asy_enb <= '1' when mode = '0' and done_reg = '0' else '0';

  process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
        state_reg     <= ST_IDLE;
        sdp_addra_reg <= (others => '0');
        sdp_addrb_reg <= (others => '0');
        sdp_di_reg    <= (others => '0');
        asy_pa_addr_reg <= (others => '0');
        asy_pa_di_reg <= (others => '0');
        sdp_we_reg    <= '0';
        op_we_reg     <= '0';
        op_din_reg    <= (others => '0');
        op_addr_reg   <= (others => '0');
        averages_reg  <= (others => '0');
        tready_reg    <= '0';
        done_reg      <= '0';
      else
        state_reg     <= state_next;
        sdp_addra_reg <= sdp_addra_next;
        sdp_addrb_reg <= sdp_addrb_next;
        sdp_di_reg    <= sdp_di_next;
        asy_pa_addr_reg <= asy_pa_addr_next;
        asy_pa_di_reg<= asy_pa_di_next;
        sdp_we_reg   <= sdp_we_next;
        op_we_reg    <= op_we_next;
        op_din_reg   <= op_din_next;
        op_addr_reg  <= op_addr_next;
        averages_reg <= averages_next;
        tready_reg   <= tready_next;
        done_reg     <= done_next;
      end if;
    end if;
  end process;

  sdp_addra_next <= sdp_addrb_reg;

  --Next state logic
  process(state_reg, start, mode, trig_i, restart, nsamples, naverages,
    sdp_addrb_reg, op_addr_reg, asy_pa_addr_reg, s_axis_tvalid, averages_reg)
    variable dinbv : std_logic_vector(2*ADC_DATA_WIDTH-1 downto 0) := (others => '0');
  begin
    state_next    <= state_reg;  
    sdp_addrb_next<= sdp_addrb_reg;
    sdp_di_next   <= sdp_di_reg; --(others => '0');
    asy_pa_addr_next<= asy_pa_addr_reg;
    asy_pa_di_next  <= asy_pa_di_reg; --(others => '0');
    sdp_we_next   <= '0';
    op_we_next    <= '0';
    op_din_next   <= op_din_reg; 
    op_addr_next  <= op_addr_reg;
    tready_next   <= tready_reg;
    averages_next <= averages_reg;
    done_next     <= done_reg;

    case state_reg is
      when ST_IDLE => -- Start
        READOUT_State_Mon <= "000"; --state mon
        sdp_addrb_next    <= (others => '0');
        sdp_di_next       <= (others => '0');
        sdp_we_next       <= '1';
        asy_pa_addr_next  <= (others => '0');
        asy_pa_di_next    <= (others => '0');
        averages_next     <= (others => '0');
        op_addr_next      <= (others => '1');
        tready_next       <= '0';
        done_next         <= '0';
        dinbv             := (others => '0');
        if start = '1' then
          state_next  <= ST_WAIT_TRIG;
        else
          state_next  <= ST_IDLE;
        end if;

      when ST_WAIT_TRIG => -- Wait for trigger
        READOUT_State_Mon <= "001"; --state mon
        dinbv         := (others => '0');
        if(trig_i = '1') and (s_axis_tvalid = '1') then
          tready_next  <= '1';
          if (mode = '0') then
            state_next  <= ST_AVG_SCOPE;
          else
            state_next    <= ST_AVG_N1;
          end if;
        else 
          state_next <= ST_WAIT_TRIG;
        end if;

      when ST_AVG_SCOPE => -- Measure
        READOUT_State_Mon <= "010"; --state mon
        sdp_we_next <= '1';
        sdp_addrb_next <= sdp_addrb_reg + 1;
        ASSIGN_G1: for I in 0 to RATIO-1 loop
          sdp_di_next(2*IN_DATA_WIDTH-1-I*2*ADC_DATA_WIDTH downto 2*IN_DATA_WIDTH-(I+1)*2*ADC_DATA_WIDTH) <= 
          std_logic_vector(signed(sdp_dob(2*IN_DATA_WIDTH-1-I*2*ADC_DATA_WIDTH downto 2*IN_DATA_WIDTH-(I+1)*2*ADC_DATA_WIDTH)) + 
          resize(signed(s_axis_tdata(IN_DATA_WIDTH-1-I*ADC_DATA_WIDTH downto IN_DATA_WIDTH-((I+1)*ADC_DATA_WIDTH)+4)),32));
        end loop;
        if(sdp_addrb_reg = (unsigned(nsamples)/RATIO)-1) then 
          sdp_addrb_next <= (others => '0');
          averages_next <= averages_reg + 1;
          tready_next  <= '0';
          if (averages_reg = unsigned(naverages)-1) then
            state_next  <= ST_FINISH;
          else
            state_next  <= ST_WAIT_TRIG;
          end if;
        end if;

      when ST_AVG_N1 => -- N to 1 average
        READOUT_State_Mon <= "011"; --state mon
        asy_pa_addr_next <= asy_pa_addr_reg + 1;
        ASSIGN_N: for I in 0 to RATIO-1 loop
          asy_pa_di_next(2*IN_DATA_WIDTH-1-I*2*ADC_DATA_WIDTH downto 2*IN_DATA_WIDTH-(I+1)*2*ADC_DATA_WIDTH) <= 
          std_logic_vector(signed(asy_pa_di_reg(2*IN_DATA_WIDTH-1-I*2*ADC_DATA_WIDTH downto 2*IN_DATA_WIDTH-(I+1)*2*ADC_DATA_WIDTH)) + 
          resize(signed(s_axis_tdata(IN_DATA_WIDTH-1-I*ADC_DATA_WIDTH downto IN_DATA_WIDTH-((I+1)*ADC_DATA_WIDTH)+4)),32));
        end loop;
        if(asy_pa_addr_reg = (unsigned(nsamples)/RATIO)-1) then 
          asy_pa_addr_next <= (others => '0');
          averages_next <= averages_reg + 1;
          tready_next   <= '0';
            state_next  <= ST_WRITE_AVG;
        end if;

      when ST_WRITE_AVG => -- write bramb
        READOUT_State_Mon <= "100"; --state mon
        ASSIGN_AVG1: for K in 0 to RATIO-1 loop
          dinbv := 
          std_logic_vector(signed(dinbv) + signed(asy_pa_di_reg(2*IN_DATA_WIDTH-1-K*2*ADC_DATA_WIDTH downto
          2*IN_DATA_WIDTH-(K+1)*2*ADC_DATA_WIDTH)));
        end loop;
        op_din_next <= dinbv;
        op_we_next <= '1';
        asy_pa_di_next <= (others => '0');
        op_addr_next <= op_addr_reg + 1;
          if (averages_reg = unsigned(naverages)) then
        state_next <= ST_FINISH;
      else
        state_next <= ST_WAIT_TRIG;
      end if;

      when ST_FINISH => -- done
        READOUT_State_Mon <= "101"; --state mon
        done_next  <= '1';
        if restart = '1' then
          state_next <= ST_IDLE;
        end if;
    end case;
  end process;

end rtl;
