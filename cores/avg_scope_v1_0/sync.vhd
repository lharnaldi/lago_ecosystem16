library ieee;
use ieee.std_logic_1164.all;

--synchronizer
entity sync is
  port(
        aclk     : in std_logic;
        aresetn  : in std_logic;
        in_async : in std_logic;
        out_sync : out std_logic
      );
end sync;

architecture two_ff_arch of sync is
  signal meta_reg, sync_reg  : std_logic;
  signal meta_next, sync_next: std_logic;
begin

  -- two registers
  process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn='0') then
        meta_reg <= '0';
        sync_reg <= '0';
      else
        meta_reg <= meta_next;
        sync_reg <= sync_next;
      end if;
    end if;
  end process;

  -- next-state logic
  meta_next <= in_async;
  sync_next <= meta_reg;
  -- output
  out_sync <= sync_reg;

end two_ff_arch;
