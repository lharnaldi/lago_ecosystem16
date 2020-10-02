library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_averager is
  generic (
            AXIS_TDATA_WIDTH: natural := 32;
            BRAM_DATA_WIDTH : natural := 32;
            BRAM_ADDR_WIDTH : natural := 14; --16
            AVERAGES_WIDTH  : natural := 32
          );
  port ( 
         -- System signals
         aclk              : in std_logic;
         aresetn           : in std_logic;

         -- Averager specific ports
         trig_i            : in std_logic;
         user_trig         : in std_logic;
         nsamples          : in std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0); --16-1
         naverages         : in std_logic_vector(AVERAGES_WIDTH-1 downto 0);
         finished          : out std_logic;
         averages_out      : out std_logic_vector(AVERAGES_WIDTH-1 downto 0);

         -- Slave side     
         s_axis_tready     : out std_logic;
         s_axis_tvalid     : in std_logic;
         s_axis_tdata      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

         -- BRAM port A
         bram_porta_clk    : out std_logic;
         bram_porta_rst    : out std_logic;
         bram_porta_addr   : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
         bram_porta_wrdata : out std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_porta_rddata : in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_porta_we     : out std_logic;

         -- BRAM port B
         bram_portb_clk    : out std_logic;
         bram_portb_rst    : out std_logic;
         bram_portb_addr   : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
         bram_portb_wrdata : out std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_portb_rddata : in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_portb_we     : out std_logic
       );
end axis_averager;

architecture rtl of axis_averager is

  type state_t is (
  ST_IDLE, 
  ST_WRITE_ZEROS, 
  ST_WAIT_TRIG, 
  ST_MEASURE, 
  ST_FINISH 
);
signal state_reg, state_next      : state_t;

signal addr_reg, addr_next        : std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
signal data_reg, data_next        : std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
signal tready_reg, tready_next    : std_logic;
signal wren_reg, wren_next        : std_logic;

signal averages_reg, averages_next: std_logic_vector(AVERAGES_WIDTH-1 downto 0);
signal finished_reg, finished_next: std_logic;
signal d_trig                     : std_logic;
signal trigger                    : std_logic;  

begin

  s_axis_tready     <= tready_reg;
  finished          <= finished_reg;
  averages_out      <= averages_reg;

  bram_porta_clk    <= aclk;
  bram_porta_rst    <= not aresetn;
  bram_porta_addr   <= addr_reg;
  bram_porta_wrdata <= data_reg;
  bram_porta_we     <= wren_reg;

  bram_portb_clk    <= aclk;
  bram_portb_rst    <= not aresetn;
  bram_portb_addr   <= std_logic_vector(unsigned(addr_reg)+1);
  bram_portb_wrdata <= (others => '0');
  bram_portb_we     <= '0';

  process(aclk)
  begin
    if rising_edge(aclk) then
      if (user_trig = '1') then
        d_trig <= '0';
      else 
        d_trig <= trig_i;
      end if;
    end if;
  end process;
  trigger <= trig_i when (user_trig = '1') else
             '0';
  --trigger <= '1' when (trig_i = '1') and (d_trig = '0') else
  --           '0';

  process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
        state_reg    <= ST_IDLE;
        addr_reg     <= (others => '0');
        data_reg     <= (others => '0');
        averages_reg <= (others => '0');
        wren_reg     <= '0';
        tready_reg   <= '0';
        finished_reg <= '0';
      else
        state_reg    <= state_next;
        addr_reg     <= addr_next;
        data_reg     <= data_next;
        averages_reg <= averages_next;
        wren_reg     <= wren_next;
        tready_reg   <= tready_next;
        finished_reg <= finished_next;
      end if;
    end if;
  end process;

  --Next state logic
  process(state_reg, nsamples, trigger, naverages, addr_reg, s_axis_tvalid)
  begin
    state_next    <= state_reg;  
    addr_next     <= addr_reg;
    data_next     <= data_reg;
    averages_next <= averages_reg;
    wren_next     <= wren_reg;
    tready_next   <= tready_reg;
    finished_next <= finished_reg;

    case state_reg is
      when ST_IDLE => -- Begin state
        addr_next     <= (others => '0');
        data_next     <= (others => '0');
        averages_next <= (others => '0');
        wren_next     <= '1';
        tready_next   <= '0';
        finished_next <= '0';
        state_next    <= ST_WRITE_ZEROS;

      when ST_WRITE_ZEROS =>    -- Clear BRAM state
        addr_next    <= std_logic_vector(unsigned(addr_reg) + 1);
        if(unsigned(addr_reg) = unsigned(nsamples)-1) then -- clear until all the addresses are zero
          wren_next   <= '0';
          state_next  <= ST_WAIT_TRIG;
        end if;

      when ST_WAIT_TRIG => -- Wait for trigger
        addr_next <= (others => '0');
        if(trigger = '1') then
          averages_next <= std_logic_vector(unsigned(averages_reg) + 1);
          if (unsigned(averages_reg) = unsigned(naverages)) then
            state_next  <= ST_FINISH;
            tready_next <= '0';
          else
            state_next  <= ST_MEASURE;
            tready_next <= '1';
            wren_next <= '1';
            data_next <= std_logic_vector(unsigned(bram_portb_rddata) + unsigned(s_axis_tdata));
          end if;
        end if;

      when ST_MEASURE => -- Measure
          --data_next <= std_logic_vector(unsigned(bram_portb_rddata) + unsigned(s_axis_tdata(BRAM_DATA_WIDTH-1 downto 0)));
        data_next <= std_logic_vector(unsigned(bram_portb_rddata) + unsigned(s_axis_tdata));
        if(s_axis_tvalid = '1') then
          addr_next <= std_logic_vector(unsigned(addr_reg) + 1);
          wren_next <= '1';
          if (unsigned(addr_reg) = unsigned(nsamples)-1) then
            state_next  <= ST_WAIT_TRIG;
            tready_next <= '0';
            wren_next   <= '0';
          end if;
        else
          wren_next <= '0';
        end if;
      when ST_FINISH => -- finished
        finished_next <= '1';
    end case;
  end process;

end rtl;
