library ieee;
use ieee.std_logic_1164.all;

entity edge_det is
  port(
        aclk   : in std_logic;
        aresetn: in std_logic;
        sig_i  : in std_logic;
        sig_o  : out std_logic
      );
end edge_det;

architecture rtl of edge_det is
  type state_t is (zero, edge, one);
  signal state_reg, state_next: state_t;
begin
   -- state register
  process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn='0') then
        state_reg <= zero;
      else
        state_reg <= state_next;
      end if;
    end if;
  end process;

   -- next-state logic
  process(state_reg, sig_i)
  begin
    case state_reg is
      when zero=>
        if sig_i = '1' then
          state_next <= edge;
        else
          state_next <= zero;
        end if;
      when edge =>
        if sig_i = '1' then
          state_next <= one;
        else
          state_next <= zero;
        end if;
      when one =>
        if sig_i = '1' then
          state_next <= one;
        else
          state_next <= zero;
        end if;
    end case;
  end process;

   -- Moore output logic
  sig_o <= '1' when state_reg=edge else
           '0';

end rtl;
