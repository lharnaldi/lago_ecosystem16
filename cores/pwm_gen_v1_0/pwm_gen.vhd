library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_gen is
generic (
  TDATA_WIDTH : natural := 32
);
port (
  aclk    : in std_logic;
  aresetn : in std_logic;
  cfg_i   : in std_logic_vector(TDATA_WIDTH-1 downto 0);
  pwm_o   : out std_logic);
end pwm_gen;

architecture rtl of pwm_gen is
  type state_t is (load_new_data, pwm_high, pwm_low);   
  signal state : state_t ;

begin

process(aclk)
  variable threshold_v : integer range 0 to ((2**TDATA_WIDTH)-1) := 0;
  variable count_v     : integer range 0 to ((2**TDATA_WIDTH)-1) := 0;
begin
  if rising_edge(aclk) then
    if aresetn = '0' then
      state <= load_new_data;
      pwm_o <= '0';
    else 
    case state is
      when load_new_data =>
        pwm_o <= '0';
        threshold_v := to_integer(unsigned(cfg_i));
        count_v := 0;   
        if (unsigned(cfg_i) > 0) then
          state <= pwm_high;
        elsif (unsigned(cfg_i) = 0) then
          state <= pwm_low;
        end if;

      when pwm_high =>
        pwm_o <= '1';
        count_v := count_v + 1;   
        if (count_v < ((2**TDATA_WIDTH)-1) and count_v < threshold_v) then
          state <= pwm_high;
        elsif (count_v = ((2**TDATA_WIDTH)-1)) then
          state <= load_new_data;
        elsif (count_v < ((2**TDATA_WIDTH)-1) and count_v = threshold_v) then
          state <= pwm_low;
        end if;

      when pwm_low =>
        pwm_o <= '0';
        count_v := count_v + 1;
        if (count_v < ((2**TDATA_WIDTH)-1)) then
          state <= pwm_low;
        elsif (count_v = ((2**TDATA_WIDTH)-1)) then
          state <= load_new_data;
        end if;
    end case;
    end if;
  end if;
end process;

end rtl;
