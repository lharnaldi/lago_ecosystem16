library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity averager is
  generic (
            IN_DATA_WIDTH  : natural := 128; -- ADC data width x8
            OUT_DATA_WIDTH : natural := 32;  -- AXI data width
            ADC_DATA_WIDTH : natural := 16;  -- ADC data width
            MEM_DEPTH      : natural := 10   -- Max 2**16
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
         --nsamples Must be power of 2. Minimum is 8 and maximum is 2^AW
         nsamples          : in std_logic_vector(32-1 downto 0); 
         naverages         : in std_logic_vector(32-1 downto 0);
         done              : out std_logic;
         averages_out      : out std_logic_vector(32-1 downto 0);
         -- BRAM PORTA. Reading port
         bram_porta_clk    : in std_logic;
         --bram_porta_rst    : in std_logic;
         bram_porta_wrdata : in std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
         bram_porta_we     : in std_logic;
         bram_porta_addr   : in std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
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
  constant MEM_ADDR_WIDTH : natural := log2c(MEM_DEPTH);

  type state_t is (
--  ST_WRITE_ZEROS, 
  ST_IDLE, 
  ST_WRITE_ZEROS, 
  ST_WAIT_TRIG, 
  ST_AVG_SCOPE,
  ST_AVG_N1,
  ST_WRITE_AVG,
  ST_FINISH 
);
signal state_reg, state_next      : state_t;

signal addr_reg, addr_next        : std_logic_vector(log2c(MEM_DEPTH/RATIO)-1 downto 0);
signal addr_dly_reg, addr_dly_next: std_logic_vector(log2c(MEM_DEPTH/RATIO)-1 downto 0);
signal data_reg, data_next        : std_logic_vector(IN_DATA_WIDTH-1 downto 0);
signal tready_reg, tready_next    : std_logic;

signal averages_reg, averages_next: std_logic_vector(32-1 downto 0);
signal done_reg, done_next        : std_logic;
signal dout_b_s                   : std_logic_vector(IN_DATA_WIDTH-1 downto 0);
signal addr_s                     : std_logic_vector(log2c(MEM_DEPTH)-1 downto 0);
signal brama_clk, bramb_clk       : std_logic;  
--signal brama_rst, bramb_rst       : std_logic;  
signal bramb_out                  : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
signal dinb_reg, dinb_next        : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
signal addrb_s                    : std_logic_vector(log2c(MEM_DEPTH)-1 downto 0);
signal wren_reg, wren_next        : std_logic;  
signal wrenb_reg, wrenb_next      : std_logic;  
signal web                        : std_logic;

begin

  BUFGMUX_inst: BUFGMUX
  port map (
             O  => brama_clk,      -- 1-bit output: Clock output
             I0 => aclk,           -- 1-bit input: Clock input (S=0)
             I1 => bram_porta_clk, -- 1-bit input: Clock input (S=1)
             S  => done_reg    -- 1-bit input: Clock select
           );

  s_axis_tready     <= tready_reg;
  done              <= done_reg;
  averages_out      <= averages_reg;
  addr_dly_next     <= addr_reg;
  addr_s            <= std_logic_vector(resize(unsigned(unsigned(bram_porta_addr)-1),addrb_s'length)) when (done_reg = '1') else 
                       std_logic_vector(resize(unsigned(unsigned(averages_reg)-1),addrb_s'length));
  web               <= wren_reg when (mode = '0') else '0';
  --bram_porta_rddata <= std_logic_vector(resize(unsigned(bramb_out),bram_porta_rddata'length)) when (done_reg = '1') else (others => '0');
  bram_porta_rddata <= std_logic_vector(resize(signed(bramb_out),bram_porta_rddata'length));
  --  brama_rst         <= bram_porta_rst when (done_reg = '1') and (mode = '0') else
  --                       aresetn;

  -- DP RAM
  tdp_ram_i : entity work.tdp_bram
  generic map(
               AWIDTH       => log2c(MEM_DEPTH/RATIO),
               DWIDTH       => IN_DATA_WIDTH
             )
  port map(
            clka    => aclk,
            clkb    => aclk,
            ena     => '1',
            enb     => '1',
            wea     => wren_reg,
            web     => '0',
            addra   => addr_dly_reg,
            addrb   => addr_reg,
            dia     => data_reg,
            dib     => (others => '0'),
            doa     => open,
            dob     => dout_b_s
          );

  -- ASYMMETRIC RAM
  -- Port A -> AXI IF
  -- Port B -> same as WIDER BRAM
  ram_asy : entity work.asym_ram_tdp
  generic map
  (
    WIDTHA      => ADC_DATA_WIDTH, 
    ADDRWIDTHA  => log2c(MEM_DEPTH),
    WIDTHB      => IN_DATA_WIDTH,
    ADDRWIDTHB  => log2c(MEM_DEPTH/RATIO)
  )
  port map
  (
    --portA same as op_ram
    clka        => brama_clk,
    ena         => '1',
    wea         => wrenb_reg,
    addra       => addr_s,
    dia         => dinb_reg,
    doa         => bramb_out,

    --portB same as portA in dp_ram
    clkb        => aclk, --brama_clk,
    enb         => '1',
    web         => web, --wren_reg,
    addrb       => addr_dly_reg,
    dib         => data_reg,
    dob         => open
  );

  process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
        state_reg    <= ST_IDLE;
        --state_reg    <= ST_WRITE_ZEROS;
        addr_reg     <= (others => '0');
        addr_dly_reg <= (others => '0');
        data_reg     <= (others => '0');
        averages_reg <= (others => '0');
        dinb_reg     <= (others => '0');
        tready_reg   <= '0';
        done_reg     <= '0';
        wren_reg     <= '0';
        wrenb_reg    <= '0';
      else
        state_reg    <= state_next;
        addr_reg     <= addr_next;
        addr_dly_reg <= addr_dly_next;
        data_reg     <= data_next;
        dinb_reg     <= dinb_next;
        averages_reg <= averages_next;
        tready_reg   <= tready_next;
        done_reg     <= done_next;
        wren_reg     <= wren_next;
        wrenb_reg    <= wrenb_next;
      end if;
    end if;
  end process;

  --Next state logic
  process(state_reg, start, mode, trig_i, restart, nsamples, naverages, addr_reg, s_axis_tvalid)
    variable dinbv : std_logic_vector(ADC_DATA_WIDTH-1 downto 0) := (others => '0');
  begin
    state_next    <= state_reg;  
    addr_next     <= addr_reg;
    data_next     <= data_reg;
    averages_next <= averages_reg;
    wren_next     <= wren_reg; 
    wrenb_next    <= wrenb_reg; 
    tready_next   <= tready_reg;
    done_next     <= done_reg;
    dinb_next     <= dinb_reg;
    dinbv         := (others => '0');

    case state_reg is
      --when ST_WRITE_ZEROS =>    -- Clear BRAM state one time case
      --  wren_next     <= '1';
      --  wrenb_next     <= '1';
      --  addr_next <= std_logic_vector(unsigned(addr_reg) + 1);
      --  if(unsigned(addr_reg) = unsigned(nsamples)/(IN_DATA_WIDTH/ADC_DATA_WIDTH)) then 
      --    wren_next  <= '0';
      --    wrenb_next  <= '0';
      --    addr_next  <= (others => '0');
      --    state_next <= ST_IDLE;
      --  end if;

      when ST_IDLE => -- Start
        addr_next     <= (others => '0');
        data_next     <= (others => '0');
        averages_next <= (others => '0');
        wren_next     <= '0';
        wrenb_next    <= '0';
        tready_next   <= '0';
        done_next     <= '0';
        dinb_next     <= (others => '0');
        if start = '1' then
          state_next  <= ST_WRITE_ZEROS;
          --state_next  <= ST_WAIT_TRIG;
        else
          state_next  <= ST_IDLE;
        end if;

      when ST_WRITE_ZEROS =>    -- Clear BRAM state
        wren_next     <= '1';
        wrenb_next     <= '1';
        addr_next <= std_logic_vector(unsigned(addr_reg) + 1);
        --if(unsigned(addr_reg) = unsigned(nsamples)/(IN_DATA_WIDTH/ADC_DATA_WIDTH)) then 
        if(unsigned(addr_reg) = unsigned(nsamples)/RATIO) then 
          wren_next  <= '0';
          wrenb_next  <= '0';
          addr_next  <= (others => '0');
          state_next <= ST_WAIT_TRIG;
        end if;

      when ST_WAIT_TRIG => -- Wait for trigger
        --wrenb_next <= '0';
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
        --ASSIGN_G: for I in 0 to (IN_DATA_WIDTH/ADC_DATA_WIDTH)-1 loop
        ASSIGN_G: for I in 0 to RATIO-1 loop
          data_next(IN_DATA_WIDTH-1-I*ADC_DATA_WIDTH downto IN_DATA_WIDTH-(I+1)*ADC_DATA_WIDTH) <= 
          std_logic_vector(signed(dout_b_s(IN_DATA_WIDTH-1-I*ADC_DATA_WIDTH downto IN_DATA_WIDTH-(I+1)*ADC_DATA_WIDTH)) + 
          signed(s_axis_tdata(IN_DATA_WIDTH-1-I*ADC_DATA_WIDTH downto IN_DATA_WIDTH-(I+1)*ADC_DATA_WIDTH)));
        end loop;
        wren_next    <= '1';
        addr_next   <= std_logic_vector(unsigned(addr_reg) + 1);
        --if (unsigned(addr_reg) = unsigned(nsamples)/(IN_DATA_WIDTH/ADC_DATA_WIDTH)) then
        if (unsigned(addr_reg) = unsigned(nsamples)/RATIO) then
          averages_next <= std_logic_vector(unsigned(averages_reg) + 1);
          addr_next   <= (others => '0');
          tready_next <= '0';
          wren_next <= '0';
          if (unsigned(averages_reg) = unsigned(naverages)-1) then
            state_next  <= ST_FINISH;
          else
            state_next  <= ST_WAIT_TRIG;
          end if;
        end if;

      when ST_AVG_N1 => -- N to 1 average
        --ASSIGN_N: for I in 0 to (IN_DATA_WIDTH/ADC_DATA_WIDTH)-1 loop
        ASSIGN_N: for I in 0 to RATIO-1 loop
          data_next(IN_DATA_WIDTH-1-I*ADC_DATA_WIDTH downto IN_DATA_WIDTH-(I+1)*ADC_DATA_WIDTH) <= 
          std_logic_vector(signed(data_reg(IN_DATA_WIDTH-1-I*ADC_DATA_WIDTH downto IN_DATA_WIDTH-(I+1)*ADC_DATA_WIDTH)) + 
          signed(s_axis_tdata(IN_DATA_WIDTH-1-I*ADC_DATA_WIDTH downto IN_DATA_WIDTH-(I+1)*ADC_DATA_WIDTH)));
        end loop;
        wren_next    <= '1';
        addr_next <= std_logic_vector(unsigned(addr_reg) + 1);
        --if (unsigned(addr_reg) = unsigned(nsamples)/(IN_DATA_WIDTH/ADC_DATA_WIDTH)) then
        if (unsigned(addr_reg) = unsigned(nsamples)/RATIO) then
          averages_next <= std_logic_vector(unsigned(averages_reg) + 1);
          addr_next   <= (others => '0');
          tready_next <= '0';
          wren_next <= '0';
          --ASSIGN_AVG: for K in 0 to (IN_DATA_WIDTH/ADC_DATA_WIDTH)-1 loop
          ASSIGN_AVG: for K in 0 to RATIO-1 loop
            dinbv := 
            std_logic_vector(signed(dinbv) + signed(data_reg(IN_DATA_WIDTH-1-K*ADC_DATA_WIDTH downto IN_DATA_WIDTH-(K+1)*ADC_DATA_WIDTH)));
          end loop;
          dinb_next <= dinbv;
          wrenb_next   <= '1';
          if (unsigned(averages_reg) = unsigned(naverages)-1) then
            state_next  <= ST_FINISH;
          else
            state_next  <= ST_WRITE_AVG;
          end if;
        end if;

      when ST_WRITE_AVG => -- write bramb
        wrenb_next   <= '0';
        data_next <= (others => '0');
        state_next <= ST_WAIT_TRIG;

      when ST_FINISH => -- done
        wrenb_next <= '0';
        done_next  <= '1';
        if restart = '1' then
          --wren_next <= '1';
          --data_next <= (others => '0');
          state_next <= ST_IDLE;
        end if;
    end case;
  end process;

end rtl;
