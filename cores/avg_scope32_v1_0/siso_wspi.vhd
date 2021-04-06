library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity shift_reg_vect is 
  generic(
  DWIDTH : natural := 32;
  DRATIO : natural := 8
         );
  port(
  aclk   : in std_logic;
  --serin  : in std_logic_vector(DWIDTH-1 downto 0);
  load   : in std_logic;
  parin  : in std_logic_vector((DRATIO*DWIDTH)-1 downto 0); 
  serout : out std_logic_vector(DWIDTH-1 downto 0)
); 
end shift_reg_vect;

architecture rtl of shift_reg_vect is
  type vect_t is array (0 to DRATIO-1) of std_logic_vector(DWIDTH-1 downto 0);
  signal tmp : std_logic_vector((DRATIO*DWIDTH)-1 downto 0); --vect_t;
  signal ZERO : std_logic_vector(DWIDTH-1 downto 0) := (others => '0');

begin 

  process(aclk) 
  begin 
    if rising_edge(aclk) then 
      --for i in 0 to DRATIO-1 loop
        if (load = '1') then
          --tmp(i) <= parin((DRATIO*DWIDTH)-1-i*DWIDTH downto (DRATIO*DWIDTH)-(i+1)*DWIDTH);
          tmp <= parin;
        else 
          tmp <= tmp((DRATIO*DWIDTH)-1-32 downto 0) & ZERO;
        end if; 
      --end loop;
    end if; 
  end process; 

  serout <= tmp((DRATIO*DWIDTH)-1 downto (DRATIO*DWIDTH)-32);

end rtl; 
