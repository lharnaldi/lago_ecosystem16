library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lock_det is
port(
  aclk         : in std_logic;
  aresetn      : in std_logic;
  ref_i        : in std_logic;
  dds_sync_i   : in std_logic;
  locked_o     : out std_logic
);
end lock_det;

architecture rtl of lock_det is

signal ref_reg, ref_next: std_logic;
signal ref_period_cntr_reg, ref_period_cntr_next : std_logic_vector(32-1 downto 0);
signal ref_period_reg, ref_period_next : std_logic_vector(32-1 downto 0);
signal ref_cntr_done_reg, ref_cntr_done_next: std_logic;
signal dds_period_cntr_reg, dds_period_cntr_next : std_logic_vector(32-1 downto 0);
signal dds_period_reg, dds_period_next : std_logic_vector(32-1 downto 0);
signal dds_cntr_done_reg, dds_cntr_done_next: std_logic;
signal dds_reg, dds_next: std_logic;


begin

--Locked state detector
process(aclk)
begin
if rising_edge(aclk) then
  if aresetn = '0' then
    ref_reg <= '0';
    dds_reg <= '0';
    ref_period_reg <= (others=>'0');
    dds_period_reg <= (others=>'0');
    ref_cntr_done_reg <= '0';
    dds_cntr_done_reg <= '0';
    ref_period_cntr_reg <= (others=>'0');
    dds_period_cntr_reg <= (others=>'0');
  else
    ref_reg <= ref_next;
    dds_reg <= dds_next;
    ref_period_reg <= ref_period_next;
    dds_period_reg <= dds_period_next;
    ref_cntr_done_reg <= ref_cntr_done_next;
    dds_cntr_done_reg <= dds_cntr_done_next;
    ref_period_cntr_reg <= ref_period_cntr_next;
    dds_period_cntr_reg <= dds_period_cntr_next;
  end if;
end if;
end process;

 --next state logic
 ref_next        <= ref_i;

 dds_next        <= dds_sync_i;

 ref_cntr_done_next  <= '1' when ((ref_next = '0') and (ref_reg = '1') and (ref_cntr_done_reg = '0')) else
                         '0' when ((ref_next = '1') and (ref_reg = '0') and (ref_cntr_done_reg = '1')) else
                         ref_cntr_done_reg;

 dds_cntr_done_next  <= '1' when ((dds_next = '0') and (dds_reg = '1') and (dds_cntr_done_reg = '0')) else
                         '0' when ((dds_next = '1') and (dds_reg = '0') and (dds_cntr_done_reg = '1')) else
                         dds_cntr_done_reg;

 ref_period_cntr_next <= (others => '0') when ((ref_next = '1') and (ref_reg = '0') and (ref_cntr_done_reg = '1')) else
                         std_logic_vector(unsigned(ref_period_cntr_reg) + 1);

 dds_period_cntr_next <= (others => '0') when ((dds_next = '1') and (dds_reg = '0') and (dds_cntr_done_reg = '1')) else
                         std_logic_vector(unsigned(dds_period_cntr_reg) + 1);

 ref_period_next <= ref_period_cntr_reg when ((ref_next = '0') and (ref_reg = '1') and (ref_cntr_done_reg = '0')) else
                    ref_period_reg;

 dds_period_next <= dds_period_cntr_reg when ((dds_next = '0') and (dds_reg = '1') and (dds_cntr_done_reg = '0')) else
                    dds_period_reg;

 --output
                  --if dds period is within +/- 25% of ref period, turn on local lock signal. 3/4 < x > 5/4
 locked_o        <= '1' when ((unsigned(dds_period_reg) > (3*unsigned(ref_period_reg)/4)) and (unsigned(dds_period_reg) < (5*unsigned(ref_period_reg)/4))) else '0';

end rtl;

