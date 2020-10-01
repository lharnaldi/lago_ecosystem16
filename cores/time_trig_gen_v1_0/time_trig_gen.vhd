library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity time_trig_gen is
  port (
    aclk    : in std_logic;
    aresetn : in std_logic;
    cfg_data: in std_logic_vector(32-1 downto 0);
    trig_o  : out std_logic
    );
end time_trig_gen;

architecture rtl of time_trig_gen is

  signal cntr_reg, cntr_next : std_logic_vector(32-1 downto 0);
  signal trig_reg, trig_next : std_logic;
  signal comp_reg, comp_next : std_logic;

begin

 process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
        cntr_reg <= (others => '0');
        trig_reg <= '0';
        comp_reg <= '0';
      else
        cntr_reg <= cntr_next;
        trig_reg <= trig_next;
        comp_reg <= comp_next;
      end if;
    end if;
  end process;
  
  comp_next <= '0' when (unsigned(cntr_reg) = unsigned(cfg_data)-1) else 
               '1';

  cntr_next <= std_logic_vector(unsigned(cntr_reg) + 1) when (comp_reg = '1') else
               (others => '0') when (comp_reg = '0') else --reset
               cntr_reg;

  trig_next <= '1' when (unsigned(cntr_reg) = unsigned(cfg_data)-1) else 
               '0';
 
  trig_o    <= trig_reg;

end rtl;
