library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_histogram is
  generic (
            AXIS_TDATA_WIDTH: natural := 16;
            BRAM_DATA_WIDTH : natural := 32;
            BRAM_ADDR_WIDTH : natural := 14
          );
  port ( 
         -- System signals
         aclk              : in std_logic;
         aresetn           : in std_logic;

         -- Slave side
         s_axis_tready     : out std_logic;
         s_axis_tvalid     : in std_logic;
         s_axis_tdata      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

         -- BRAM port
         bram_porta_clk    : out std_logic;
         bram_porta_rst    : out std_logic;
         bram_porta_addr   : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
         bram_porta_wrdata : out std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_porta_rddata : in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_porta_we     : out std_logic
       );
end axis_histogram;

architecture rtl of axis_histogram is

  type state_t is (
  ST_IDLE, 
  ST_WRITE_ZEROS, 
  ST_READ_ADDR, 
  ST_DELAY1, 
  ST_INC_DATA, 
  ST_DELAY2
);
signal state_reg, state_next : state_t;

signal addr_reg, addr_next     : std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
signal data_reg, data_next     : std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
signal tready_reg, tready_next : std_logic;
signal wren_reg, wren_next     : std_logic;
signal wren_s                  : std_logic;

begin

  s_axis_tready     <= tready_reg;

  bram_porta_clk    <= aclk;
  bram_porta_rst    <= not aresetn;
  bram_porta_addr   <= addr_reg when (wren_reg = '1') else 
                       s_axis_tdata(BRAM_ADDR_WIDTH-1 downto 0);
  bram_porta_wrdata <= data_reg;
  bram_porta_we     <= wren_reg;

  process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
        state_reg  <= ST_IDLE;
        addr_reg   <= (others => '0');
        data_reg   <= (others => '0');
        tready_reg <= '0';
        wren_reg   <= '0';
      else
        state_reg  <= state_next;
        addr_reg   <= addr_next;
        data_reg   <= data_next;
        tready_reg <= tready_next;
        wren_reg   <= wren_next;
      end if;
    end if;
  end process;

  wren_s <= '1' when (bram_porta_rddata = (bram_porta_rddata'range => '1')) else 
            '0';

  --Next state logic
  process(state_reg, addr_reg, s_axis_tvalid)
  begin
    state_next  <= state_reg;  
    addr_next   <= addr_reg;
    data_next   <= data_reg;
    tready_next <= tready_reg;
    wren_next   <= wren_reg;

    case state_reg is
      when ST_IDLE =>
        addr_next     <= (others => '0');
        data_next     <= (others => '0');
        wren_next     <= '1';
        state_next    <= ST_WRITE_ZEROS;
      when ST_WRITE_ZEROS =>
        addr_next     <= std_logic_vector(unsigned(addr_reg) + 1);
        if (addr_reg = (addr_reg'range => '1')) then
          tready_next <= '1';
          wren_next   <= '0';
          state_next  <= ST_READ_ADDR;
        end if;
      when ST_READ_ADDR => 
        if (s_axis_tvalid = '1') then
          addr_next   <= s_axis_tdata(BRAM_ADDR_WIDTH-1 downto 0);
          tready_next <= '0';
          state_next  <= ST_DELAY1;
        end if;
      when ST_DELAY1 => 
        state_next    <= ST_INC_DATA;
      when ST_INC_DATA => 
        data_next     <= std_logic_vector(unsigned(bram_porta_rddata) + 1);
        wren_next     <= not wren_s; --(and bram_porta_rddata); 
        state_next    <= ST_DELAY2;
      when ST_DELAY2 => 
        tready_next   <= '1';
        wren_next     <= '0';
        state_next    <= ST_READ_ADDR;
    end case;
  end process;

end rtl;
