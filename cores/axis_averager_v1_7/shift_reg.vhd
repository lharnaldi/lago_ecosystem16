library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shift_register is
  generic( 
           SR_WIDTH: integer := 32;
           SR_DEPTH: integer := 2
         );
  port ( 
         aclk   : in  std_logic;
         aresetn: in  std_logic;
         en     : in  std_logic;
         data_i : in  std_logic_vector(SR_WIDTH-1 downto 0);
         data_o : out std_logic_vector(SR_WIDTH-1 downto 0));
end shift_register;

architecture rtl of shift_register is
  type fifo_t is array (SR_DEPTH-1 downto 0) of std_logic_vector(SR_WIDTH-1 downto 0);
  signal fifo_s: fifo_t := (others =>(others => '0'));

begin
  shift: process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        fifo_s <= (others => (others => '0'));
      else
        if en = '1' then
          fifo_s(0) <= data_i;
          for i in 0 to SR_DEPTH-2 loop
            fifo_s(i+1) <= fifo_s(i);
          end loop;
        end if;
      end if;
    end if;
  end process;
  data_o <= fifo_s(SR_DEPTH-1);

end rtl;
