library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity averager is
  generic (
            AXIS_TDATA_WIDTH: natural := 128; -- ADC data width x8
            AXI_DATA_WIDTH  : natural := 32;  -- AXI data width
            ADC_DATA_WIDTH  : natural := 16;  -- ADC data width
            MEM_ADDR_WIDTH  : natural := 10 -- Max 2**16
          );
  port ( 
         -- System signals
         aclk              : in std_logic;
         aresetn           : in std_logic;

         -- Averager specific ports
         start_i           : in std_logic;
         trig_en           : in std_logic;
         mode              : in std_logic; --0- (default) avg scope, 1-avg nsamples to one value
         trig_i            : in std_logic;
         --nsamples Must be power of 2. Minimum is 8 and maximum is 2^AW
         nsamples          : in std_logic_vector(AXI_DATA_WIDTH-1 downto 0); 
         naverages         : in std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
         finished          : out std_logic;
         averages_out      : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
         -- BRAM PORTA. Reading port
         bram_porta_clk    : in std_logic;
         bram_porta_rst    : in std_logic;
         bram_porta_wrdata : in std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
         bram_porta_we     : in std_logic;
         bram_porta_addr   : in std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
         bram_porta_rddata : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

         -- Slave side     
         s_axis_tready     : out std_logic;
         s_axis_tvalid     : in std_logic;
         s_axis_tdata      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
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

  constant RATIO : natural := AXIS_TDATA_WIDTH/ADC_DATA_WIDTH;
  constant MEM_DEPTH: natural := 2**MEM_ADDR_WIDTH;

  type state_t is (
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
signal data_reg, data_next        : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
signal tready_reg, tready_next    : std_logic;
signal wren                       : std_logic;

signal averages_reg, averages_next: std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal finished_reg, finished_next: std_logic;
signal trig_s                     : std_logic;  
signal dout_b_s                   : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
signal addr_s                     : std_logic_vector(log2c(MEM_DEPTH)-1 downto 0);
signal brama_clk, bramb_clk       : std_logic;  
--signal brama_rst, bramb_rst       : std_logic;  
signal web_s                      : std_logic;  
signal bramb_out                  : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
signal dinb_reg, dinb_next        : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
--signal addrb_s                    : std_logic_vector(log2c(MEM_DEPTH)-1 downto 0);
signal wren_reg, wren_next        : std_logic;  
signal wrenb_reg, wrenb_next      : std_logic;  
signal web                        : std_logic;

begin

  s_axis_tready     <= tready_reg;
  finished          <= finished_reg;
  averages_out      <= averages_reg;
  trig_s            <= trig_i when (trig_en = '1') else
                       '0';
  addr_dly_next     <= addr_reg;

  addr_s            <= bram_porta_addr when (finished_reg = '1') else 
                       std_logic_vector(resize(unsigned(unsigned(averages_reg)-1),addr_s'length));

  web               <= wren_reg when (mode = '0') else '0';

  bram_porta_rddata <= std_logic_vector(resize(unsigned(bramb_out),bram_porta_rddata'length)) when (finished_reg = '1') else (others => '0');

  BUFGMUX_inst: BUFGMUX
  port map (
             O  => brama_clk,      -- 1-bit output: Clock output
             I0 => aclk,           -- 1-bit input: Clock input (S=0)
             I1 => bram_porta_clk, -- 1-bit input: Clock input (S=1)
             S  => finished_reg    -- 1-bit input: Clock select
           );

   -- RAM
  ram_i : entity work.dp_ram_sync
  generic map
  (
    ADDR_WIDTH  => log2c(MEM_DEPTH/RATIO),
    DATA_WIDTH  => AXIS_TDATA_WIDTH
  )
  port map
  (
    clk     => aclk,
    we      => wren_reg,
    addr_a  => addr_dly_reg,
    addr_b  => addr_reg, 
    din_a   => data_reg,
    dout_a  => open,
    dout_b  => dout_b_s
  );

  -- ASYMMETRIC RAM
  -- Port A -> AXI IF
  -- Port B -> same as WIDER BRAM
  ram_asy : entity work.asym_ram_tdp
  generic map
  (
    INIT_RAM    => '1',
    WIDTHA      => ADC_DATA_WIDTH, 
    ADDRWIDTHA  => log2c(MEM_DEPTH),
    WIDTHB      => AXIS_TDATA_WIDTH,
    ADDRWIDTHB  => log2c(MEM_DEPTH/RATIO)
  )
  port map
  (
    --portA same as op_ram
    clkA        => brama_clk,
    enA         => '1',
    weA         => wrenb_reg,
    addrA       => addr_s,
    diA         => dinb_reg,
    doA         => bramb_out,

    --portB same as portA in dp_ram
    clkB        => aclk,
    enB         => '1',
    weB         => web, --wren_reg,
    addrB       => addr_dly_reg,
    diB         => data_reg,
    doB         => open
  );

  process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
        state_reg    <= ST_IDLE;
        addr_reg     <= (others => '0');
        addr_dly_reg <= (others => '0');
        data_reg     <= (others => '0');
        averages_reg <= (others => '0');
        dinb_reg     <= (others => '0');
        tready_reg   <= '0';
        finished_reg <= '0';
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
        finished_reg <= finished_next;
        wren_reg     <= wren_next;
        wrenb_reg    <= wrenb_next;
      end if;
    end if;
  end process;

  --Next state logic
  process(state_reg, start_i, mode, trig_s, nsamples, naverages, addr_reg, s_axis_tvalid)
    variable dinbv : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  begin
    state_next    <= state_reg;  
    addr_next     <= addr_reg;
    data_next     <= data_reg;
    averages_next <= averages_reg;
    wren_next     <= wren_reg; 
    wrenb_next    <= wrenb_reg; 
    tready_next   <= tready_reg;
    finished_next <= finished_reg;
    dinb_next     <= dinb_reg;
    dinbv         := (others => '0');

    case state_reg is
      when ST_IDLE => -- Start
        addr_next     <= (others => '0');
        data_next     <= (others => '0');
        averages_next <= (others => '0');
        wren_next     <= '0';
        wrenb_next    <= '0';
        tready_next   <= '0';
        finished_next <= '0';
        dinb_next     <= (others => '0');
        if start_i = '1' then
          state_next    <= ST_WRITE_ZEROS;
        else
          state_next    <= ST_IDLE;
        end if;

      when ST_WRITE_ZEROS =>    -- Clear BRAM state
        wren_next     <= '1';
        wrenb_next     <= '1';
        addr_next <= std_logic_vector(unsigned(addr_reg) + 1);
        if(unsigned(addr_reg) = unsigned(nsamples)/(AXIS_TDATA_WIDTH/ADC_DATA_WIDTH)) then 
          wren_next  <= '0';
          wrenb_next  <= '0';
          addr_next  <= (others => '0');
          state_next <= ST_WAIT_TRIG;
        end if;

      when ST_WAIT_TRIG => -- Wait for trigger
        --wrenb_next <= '0';
        if(trig_s = '1') and (s_axis_tvalid = '1') then
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
        ASSIGN_G: for I in 0 to (AXIS_TDATA_WIDTH/ADC_DATA_WIDTH)-1 loop
          data_next(AXIS_TDATA_WIDTH-1-I*ADC_DATA_WIDTH downto AXIS_TDATA_WIDTH-(I+1)*ADC_DATA_WIDTH) <= 
          std_logic_vector(unsigned(dout_b_s(AXIS_TDATA_WIDTH-1-I*ADC_DATA_WIDTH downto AXIS_TDATA_WIDTH-(I+1)*ADC_DATA_WIDTH)) + 
          unsigned(s_axis_tdata(AXIS_TDATA_WIDTH-1-I*ADC_DATA_WIDTH downto AXIS_TDATA_WIDTH-(I+1)*ADC_DATA_WIDTH)));
        end loop;
        wren_next    <= '1';
        addr_next   <= std_logic_vector(unsigned(addr_reg) + 1);
        if (unsigned(addr_reg) = unsigned(nsamples)/(AXIS_TDATA_WIDTH/ADC_DATA_WIDTH)) then
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
        ASSIGN_N: for I in 0 to (AXIS_TDATA_WIDTH/ADC_DATA_WIDTH)-1 loop
          data_next(AXIS_TDATA_WIDTH-1-I*ADC_DATA_WIDTH downto AXIS_TDATA_WIDTH-(I+1)*ADC_DATA_WIDTH) <= 
          std_logic_vector(unsigned(data_reg(AXIS_TDATA_WIDTH-1-I*ADC_DATA_WIDTH downto AXIS_TDATA_WIDTH-(I+1)*ADC_DATA_WIDTH)) + 
          unsigned(s_axis_tdata(AXIS_TDATA_WIDTH-1-I*ADC_DATA_WIDTH downto AXIS_TDATA_WIDTH-(I+1)*ADC_DATA_WIDTH)));
        end loop;
        wren_next    <= '1';
        addr_next <= std_logic_vector(unsigned(addr_reg) + 1);
        if (unsigned(addr_reg) = unsigned(nsamples)/(AXIS_TDATA_WIDTH/ADC_DATA_WIDTH)) then
          averages_next <= std_logic_vector(unsigned(averages_reg) + 1);
          addr_next   <= (others => '0');
          tready_next <= '0';
          wren_next <= '0';
          ASSIGN_AVG: for K in 0 to (AXIS_TDATA_WIDTH/ADC_DATA_WIDTH)-1 loop
            dinbv := 
            std_logic_vector(unsigned(dinbv) + unsigned(data_reg(AXIS_TDATA_WIDTH-1-K*ADC_DATA_WIDTH downto AXIS_TDATA_WIDTH-(K+1)*ADC_DATA_WIDTH)));
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

      when ST_FINISH => -- finished
        wrenb_next <= '0';
        finished_next <= '1';
    end case;
  end process;

end rtl;
