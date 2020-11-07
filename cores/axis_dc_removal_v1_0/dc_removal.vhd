-- See WP279 from Xilinx
library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dc_removal is
  generic(
           DATA_WIDTH : integer := 16
         );
  port (
         aclk    : in std_logic;
         aresetn : in std_logic;
         k_i     : in std_logic_vector(DATA_WIDTH-1 downto 0);
         data_i  : in std_logic_vector(DATA_WIDTH-1 downto 0);
         data_o  : out std_logic_vector(DATA_WIDTH-1 downto 0)
       );
end dc_removal;

architecture rtl of dc_removal is
  signal k_reg, k_next     : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal d0_reg, d0_next   : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal d11_reg, d11_next : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal d12_reg, d12_next : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal d21_reg, d21_next : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal d22_reg, d22_next : std_logic_vector(2*DATA_WIDTH-1 downto 0);
  signal d31_reg, d31_next : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal d32_reg, d32_next : std_logic_vector(2*DATA_WIDTH-1 downto 0);
  signal d4_reg, d4_next   : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal mult_s            : std_logic_vector(2*DATA_WIDTH-1 downto 0);
  signal sub_s             : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal sub2_s            : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal data_fbk          : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        k_reg   <= (others => '0');     
        d0_reg  <= (others => '0');     
        d11_reg <= (others => '0');     
        d12_reg <= (others => '0');     
        d21_reg <= (others => '0');     
        d22_reg <= (others => '0');     
        d31_reg <= (others => '0');     
        d32_reg <= (others => '0');     
        d4_reg  <= (others => '0');     
      else
        k_reg   <= k_next;
        d0_reg  <= d0_next;
        d11_reg <= d11_next;
        d12_reg <= d12_next;
        d21_reg <= d21_next;
        d22_reg <= d22_next;
        d31_reg <= d31_next;
        d32_reg <= d32_next;
        d4_reg  <= d4_next;
      end if;
    end if;
  end process;

  k_next <= k_i;

  d0_next <= data_i;

  d11_next <= d0_reg;

  sub_s <= std_logic_vector(signed(d0_reg) - signed(data_fbk));

  d12_next <= sub_s; 

  d21_next <= d11_reg; 

  mult_s <= std_logic_vector(signed(k_reg) * signed(d12_reg));

  d22_next <= mult_s;

  d31_next <= d21_reg; 

  d32_next <= std_logic_vector(signed(d32_reg) + signed(d22_reg));

  data_fbk <= d32_reg(2*DATA_WIDTH-1 downto DATA_WIDTH);

  sub2_s <= std_logic_vector(signed(d31_reg) - signed(data_fbk));

  d4_next <= sub2_s;

  data_o <= d4_reg;

end rtl;     
