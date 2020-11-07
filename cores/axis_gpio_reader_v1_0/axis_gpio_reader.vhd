library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity axis_gpio_reader is
  generic (
            AXIS_TDATA_WIDTH: natural := 32
          );
  port (
         -- System signals
         aclk : in std_logic;

         gpio_data : inout std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

         -- Master side
         m_axis_tdata : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         m_axis_tvalid : out std_logic
       );
end axis_gpio_reader;

architecture rtl of axis_gpio_reader is

  type int_data_t is array (1 downto 0) of std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  signal int_data_reg : int_data_t;
  signal int_data_wire: std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

begin

  GPIO_G: for j in 0 to AXIS_TDATA_WIDTH-1 generate
    IOBUF_int: IOBUF 
    port map(
              O => int_data_wire(j), 
              IO => gpio_data(j), 
              I => '0', 
              T => '1'
            );
  end generate;

  process(aclk)
  begin
    if (rising_edge(aclk)) then
      int_data_reg(0) <= int_data_wire;
      int_data_reg(1) <= int_data_reg(0);
    end if;
  end process;

  m_axis_tdata <= int_data_reg(1);
  m_axis_tvalid <= '1';

end rtl;
