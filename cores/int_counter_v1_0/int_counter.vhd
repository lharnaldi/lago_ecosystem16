library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity int_counter is
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;
    int_o   : out std_logic
    );
end int_counter;

architecture rtl of int_counter is

  signal counter_reg, counter_next  : std_logic_vector(30-1 downto 0);
  signal int_reg, int_next          : std_logic;

begin

 process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
        counter_reg <= (others => '0');
        int_reg <= '0';
      else
        counter_reg <= counter_next;
        int_reg <= int_next;
      end if;
    end if;
  end process;
  
  counter_next <= std_logic_vector(unsigned(counter_reg) + 1);
  int_next <= '1' when (unsigned(counter_reg) = 0) or (unsigned(counter_reg) = 1) or (unsigned(counter_reg) = 2) else '0';
 
  int_o <= int_reg;

end rtl;
