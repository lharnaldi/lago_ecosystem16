library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_rp is
generic(
  DATA_WIDTH : integer := 24;
  MAX_CNT : integer := 156
);
port (
  aclk    : in std_logic;
  aresetn : in std_logic;
  cfg_i   : in std_logic_vector(DATA_WIDTH-1 downto 0);
  pwm_o   : out std_logic
  );
end pwm_rp;

architecture rtl of pwm_rp is
  signal bcnt_reg, bcnt_next : std_logic_vector(4-1 downto 0);
  signal b_reg, b_next : std_logic_vector(16-1 downto 0); 
  signal vcnt_reg, vcnt_next: std_logic_vector(8-1 downto 0);
  signal v_reg, v_next, v_r_reg, v_r_next : std_logic_vector(8-1 downto 0);

begin

process(aclk)
begin
if rising_edge(aclk) then
  if aresetn = '0' then
    vcnt_reg <= (others => '0');     
    bcnt_reg <= (others => '0');     
    v_reg <= (others => '0');     
    v_r_reg <= (others => '0');     
    b_reg <= (others => '0');     
  else
    vcnt_reg <= vcnt_next;
    bcnt_reg <= bcnt_next;
    v_reg <= v_next;
    v_r_reg <= v_r_next;
    b_reg <= b_next;
  end if;
end if;
end process;

 vcnt_next <= (others => '0') when unsigned(vcnt_reg) = MAX_CNT else
              std_logic_vector(unsigned(vcnt_reg)+1);
              
 bcnt_next <= std_logic_vector(unsigned(bcnt_reg) + 1) when unsigned(vcnt_reg) = MAX_CNT else
              bcnt_reg;
              
 b_next    <= cfg_i(16-1 downto 0) when (unsigned(vcnt_reg) = MAX_CNT) and (bcnt_reg = "1111") else
              "0" & b_reg(15 downto 1) when (unsigned(vcnt_reg) = MAX_CNT) and (bcnt_reg /= "1111") else
              b_reg;

 v_next    <= cfg_i(24-1 downto 16) when (unsigned(vcnt_reg) = MAX_CNT) and (bcnt_reg = "1111") else 
              v_reg;

 v_r_next  <= std_logic_vector(unsigned(v_reg) + 1) when b_reg(0) = '1' else
              v_reg;
              
 pwm_o     <= '1' when (unsigned(vcnt_reg) <= unsigned(v_r_reg)) else '0';

end rtl;     
